// deezer_pool.js — verificador del pool de ARLs de la extensión de Deezer.
// Offline: stubea `http` y `file`, así que no toca la red ni necesita
// credenciales reales.
//
// POR QUÉ EXISTE
// Deezer limita la cantidad de streams por cuenta, así que la extensión acepta
// varias credenciales (el ARL propio + un pool) y rota cuando una está muerta.
// Esa rotación es fácil de romper y el síntoma es silencioso: "Deezer dejó de
// dar audio" cuando en realidad era una credencial vencida que nunca se cambió
// por la siguiente.
//
// QUÉ VERIFICA
//   1. La credencial propia va PRIMERO, luego el pool, sin duplicados.
//   2. Si la primera del pool está muerta, rota a la siguiente y consigue sesión.
//   3. Con SOLO credenciales muertas falla con un mensaje explicativo.
//   4. Sin credenciales devuelve null (modo solo-metadata) y no rompe.
//   5. La sesión cacheada no vuelve a pegarle al gateway.
//   6. Una credencial que el gateway ACEPTA pero que Deezer rechaza al pedir
//      el audio (sin licencia para streamear) se descarta: la próxima
//      descarga usa la SIGUIENTE del pool, sin repetir la rechazada.
//
// Uso: node scripts/pruebas_extensiones/deezer_pool.js <ruta-index.js>

const fs = require("fs");
const vm = require("vm");

const RUTA = process.argv[2];
if (!RUTA) {
  console.error("FALTA la ruta del index.js de deezer");
  process.exit(2);
}
const src = fs.readFileSync(RUTA, "utf8");

const VIVO = "a".repeat(32);
const VIVO2 = "b".repeat(32);
const MUERTO = "c".repeat(32);
// Sesión válida (el gateway la acepta) pero SIN habilitación para pedir el
// audio: es el caso que antes dejaba el pool pegado en una credencial inútil.
const SIN_STREAM = "d".repeat(32);

const licenciaDe = (arl) => "LT-" + String(arl).slice(0, 4);

const intentos = []; // credenciales consultadas en el gateway
const licencias = []; // licencias usadas en media.deezer.com/v1/get_url
const descargas = []; // URLs del CDN pedidas a file.download

const sandbox = {
  console,
  Date,
  Map,
  JSON,
  Number,
  String,
  Object,
  Array,
  Error,
  isFinite,
  RegExp,
  encodeURIComponent,
  parseInt,
  parseFloat,
  setTimeout,
  log: { info() {}, warn() {}, error() {}, debug() {} },
  // md5: lo usa generateBlowfishKeyHex para la clave de descifrado del stream.
  // Sin él, el descifrado tira y la descarga "falla" sin que se vea el motivo.
  utils: {
    randomUserAgent: () => "test-agent",
    sha256: () => "hash",
    md5: () => "0123456789abcdef0123456789abcdef",
  },
  file: {
    download(url, path) {
      descargas.push({ url: url, path: path });
      return { success: true, path: path };
    },
    transformPatternedBlocks(entrada, salida, opciones, progreso) {
      if (typeof progreso === "function") progreso(10, 100);
      return { success: true, path: salida };
    },
    delete() {
      return true;
    },
  },
  registerExtension: () => true,
  URL: require("url").URL,
  http: {
    post(url, body, headers) {
      const destino = String(url || "");

      // 1) CDN: media.deezer.com/v1/get_url firma la URL del audio.
      if (destino.indexOf("media.deezer.com") >= 0) {
        const datos = JSON.parse(body || "{}");
        const licencia = String((datos && datos.license_token) || "");
        licencias.push(licencia);
        if (licencia === licenciaDe(SIN_STREAM)) {
          // Habilitada, pero sin licencia de stream: Deezer responde 200 con
          // el error ADENTRO (igual que en producción).
          return {
            statusCode: 200,
            body: JSON.stringify({
              data: [{ errors: [{ code: 4, message: "Invalid session" }] }],
            }),
          };
        }
        return {
          statusCode: 200,
          body: JSON.stringify({
            data: [
              {
                media: [
                  { sources: [{ url: "https://cdn.example/sin-perdida.mp3" }] },
                ],
              },
            ],
          }),
        };
      }

      // 2) Gateway de Deezer (getUserData / song.getData).
      const arl = String((headers && headers.Cookie) || "").replace("arl=", "");
      intentos.push(arl);
      if (arl === VIVO || arl === VIVO2 || arl === SIN_STREAM) {
        if (/method=song\.getData/.test(destino)) {
          return {
            statusCode: 200,
            body: JSON.stringify({
              results: {
                TRACK_TOKEN: "TT-" + arl.slice(0, 4),
                FILESIZE_FLAC: 4321,
                FILESIZE_MP3_128: 999,
              },
            }),
          };
        }
        return {
          statusCode: 200,
          body: JSON.stringify({
            results: {
              USER: {
                USER_ID: "777",
                OPTIONS: {
                  web_lossless: true,
                  license_token: licenciaDe(arl),
                },
              },
              checkForm: "CF",
              COUNTRY: "US",
            },
          }),
        };
      }
      return {
        statusCode: 200,
        body: JSON.stringify({ results: { USER: { USER_ID: "0" } } }),
      };
    },
    get() {
      return { statusCode: 404, body: "" };
    },
  },
};
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(src, sandbox);

let fallos = 0;
const check = (nombre, ok, extra) => {
  console.log(
    (ok ? "  ok    " : "  FALLA ") + nombre + (extra ? "  -> " + extra : ""),
  );
  if (!ok) fallos++;
};

const marcar = (l) => l.map((x) => x.slice(0, 4) + "…").join(", ");

console.log(
  "\n1) La credencial propia va PRIMERO, luego el pool (sin duplicados)",
);
const orden = sandbox.poolDesdeAjustes({
  arl: VIVO,
  arlPool: VIVO2 + "\n" + MUERTO + "\n" + VIVO,
});
check(
  "orden correcto y sin duplicados",
  orden.length === 3 && orden[0] === VIVO,
  marcar(orden),
);

console.log(
  "\n2) Rotación: la primera credencial está muerta -> usa la siguiente",
);
intentos.length = 0;
sandbox.initialize({ arlPool: MUERTO + "\n" + VIVO2 });
const sesion = sandbox.ensureArlSession();
check(
  "consiguió sesión",
  !!sesion,
  sesion
    ? "userId=" + sesion.userId + " formats=" + sesion.formats.join("/")
    : "null",
);
check(
  "rotó del muerto al vivo",
  intentos.length === 2 && intentos[0] === MUERTO && intentos[1] === VIVO2,
  intentos.map((x) => x.slice(0, 4) + "…").join(" -> "),
);

console.log("\n3) Con SOLO credenciales muertas falla claro, no en silencio");
intentos.length = 0;
sandbox.initialize({ arlPool: MUERTO });
let error = null;
try {
  sandbox.ensureArlSession();
} catch (e) {
  error = e.message;
}
check(
  "tira error explicativo",
  !!error && /Ninguna credencial del pool/.test(error),
  error,
);
check(
  "probó todas las del pool",
  intentos.length === 1,
  String(intentos.length),
);

console.log("\n4) Sin credenciales -> null (modo solo-metadata, no rompe)");
sandbox.initialize({});
check("devuelve null", sandbox.ensureArlSession() === null);

console.log("\n5) La sesión cacheada no vuelve a pegarle al gateway");
intentos.length = 0;
sandbox.initialize({ arlPool: VIVO });
sandbox.ensureArlSession();
const antes = intentos.length;
sandbox.ensureArlSession();
check(
  "no repite la llamada",
  intentos.length === antes,
  "llamadas=" + intentos.length,
);

console.log(
  "\n6) Credencial aceptada por el gateway pero rechazada al pedir el audio -> se descarta y rota",
);
intentos.length = 0;
licencias.length = 0;
descargas.length = 0;
sandbox.initialize({ arlPool: SIN_STREAM + "\n" + VIVO2 + "\n" + MUERTO });

const primera = sandbox.download("123", "flac", "C:/tmp/tema.mp3", null, null);
check(
  "la primera descarga no sale con la credencial sin stream",
  !(primera && primera.success),
  primera ? primera.error_message : "null",
);
const trasPrimera = licencias.length;
check(
  "solo intentó con la primera credencial del pool",
  trasPrimera >= 1 && licencias.every((l) => l === licenciaDe(SIN_STREAM)),
  licencias.join(" -> ") || "(sin intentos)",
);

const segunda = sandbox.download("123", "flac", "C:/tmp/tema.mp3", null, null);
check(
  "la segunda descarga sí descarga",
  !!(segunda && segunda.success),
  segunda ? segunda.file_path || segunda.error_message : "null",
);
check(
  "rotó a la SIGUIENTE credencial (no repitió la rechazada ni saltó una)",
  licencias[trasPrimera] === licenciaDe(VIVO2) &&
    licencias.slice(trasPrimera).every((l) => l === licenciaDe(VIVO2)),
  licencias.join(" -> ") || "(sin intentos)",
);
check(
  "no volvió a pedir audio con la credencial rechazada",
  licencias.slice(trasPrimera).indexOf(licenciaDe(SIN_STREAM)) < 0,
  licencias.join(" -> ") || "(sin intentos)",
);
check(
  "bajó el archivo del CDN y lo descifró",
  descargas.length === 1 &&
    descargas[0].url === "https://cdn.example/sin-perdida.mp3",
  descargas.map((d) => d.path).join(", "),
);

if (fallos) console.log("\n" + fallos + " FALLA(S)  (" + RUTA + ")");
process.exit(fallos === 0 ? 0 : 1);
