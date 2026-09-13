// deezer_pool.js — verificador del pool de ARLs de la extensión de Deezer.
// Offline: stubea `http`, así que no toca la red.
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

const intentos = [];
const sandbox = {
  console,
  Date, Map, JSON, Number, String, Object, Array, Error, isFinite, RegExp,
  encodeURIComponent, parseInt, parseFloat, setTimeout,
  log: { info() {}, warn() {}, error() {}, debug() {} },
  utils: { randomUserAgent: () => "test-agent", sha256: () => "hash" },
  file: {},
  registerExtension: () => true,
  URL: require("url").URL,
  http: {
    post(url, body, headers) {
      const arl = String((headers && headers.Cookie) || "").replace("arl=", "");
      intentos.push(arl);
      if (arl === VIVO || arl === VIVO2) {
        return {
          statusCode: 200,
          body: JSON.stringify({
            results: {
              USER: { USER_ID: "777", OPTIONS: { web_lossless: true, license_token: "LT" } },
              checkForm: "CF",
              COUNTRY: "US",
            },
          }),
        };
      }
      return { statusCode: 200, body: JSON.stringify({ results: { USER: { USER_ID: "0" } } }) };
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
  console.log((ok ? "  ok    " : "  FALLA ") + nombre + (extra ? "  -> " + extra : ""));
  if (!ok) fallos++;
};

const marcar = (l) => l.map((x) => x.slice(0, 4) + "…").join(", ");

console.log("\n1) La credencial propia va PRIMERO, luego el pool (sin duplicados)");
const orden = sandbox.poolDesdeAjustes({ arl: VIVO, arlPool: VIVO2 + "\n" + MUERTO + "\n" + VIVO });
check("orden correcto y sin duplicados", orden.length === 3 && orden[0] === VIVO, marcar(orden));

console.log("\n2) Rotación: la primera credencial está muerta -> usa la siguiente");
intentos.length = 0;
sandbox.initialize({ arlPool: MUERTO + "\n" + VIVO2 });
const sesion = sandbox.ensureArlSession();
check(
  "consiguió sesión",
  !!sesion,
  sesion ? "userId=" + sesion.userId + " formats=" + sesion.formats.join("/") : "null",
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
check("tira error explicativo", !!error && /Ninguna credencial del pool/.test(error), error);
check("probó todas las del pool", intentos.length === 1, String(intentos.length));

console.log("\n4) Sin credenciales -> null (modo solo-metadata, no rompe)");
sandbox.initialize({});
check("devuelve null", sandbox.ensureArlSession() === null);

console.log("\n5) La sesión cacheada no vuelve a pegarle al gateway");
intentos.length = 0;
sandbox.initialize({ arlPool: VIVO });
sandbox.ensureArlSession();
const antes = intentos.length;
sandbox.ensureArlSession();
check("no repite la llamada", intentos.length === antes, "llamadas=" + intentos.length);

if (fallos) console.log("\n" + fallos + " FALLA(S)  (" + RUTA + ")");
process.exit(fallos === 0 ? 0 : 1);
