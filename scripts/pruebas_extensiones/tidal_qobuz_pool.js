// tidal_qobuz_pool.js — verificador de la rotación del pool de credenciales de
// Tidal y de Qobuz. Offline: stubea `http`, así que no toca la red.
//
// POR QUÉ EXISTE
// Tidal (access token) y Qobuz (email + password) también limitan el uso por
// cuenta, así que ambas extensiones aceptan varias credenciales y rotan cuando
// una rebota con 401. Sin rotación, una credencial vencida deja a esa fuente sin
// FLAC y el síntoma es "Tidal/Qobuz ya no descarga", no "falta rotar".
//
// QUÉ VERIFICA (las dos fuentes, mismo contrato)
//   1. La credencial propia va PRIMERO y sin duplicados.
//   2. Con la primera muerta, ROTA a la siguiente y consigue sesión
//      (no se rinde en el primer 401).
//   3. Con TODAS muertas falla con código UNAUTHORIZED (no en silencio).
//   4. Tidal: sin pool directo, hasDirectTidalSession() se apaga.
//
// Uso: node scripts/pruebas_extensiones/tidal_qobuz_pool.js <ruta-tidal> <ruta-qobuz>

const fs = require("fs");
const vm = require("vm");

const RUTA_TIDAL = process.argv[2];
const RUTA_QOBUZ = process.argv[3];
if (!RUTA_TIDAL || !RUTA_QOBUZ) {
  console.error("FALTAN las rutas de tidal-web y qobuz-web");
  process.exit(2);
}

let fallos = 0;
const check = (nombre, ok, extra) => {
  console.log((ok ? "  ok    " : "  FALLA ") + nombre + (extra ? "  -> " + extra : ""));
  if (!ok) fallos++;
};

function cargar(ruta, sandbox) {
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(ruta, "utf8"), sandbox);
  return sandbox;
}

function base(extra) {
  return Object.assign(
    {
      console,
      Date, Map, JSON, Number, String, Object, Array, Error, isFinite, RegExp,
      encodeURIComponent, decodeURIComponent, parseInt, parseFloat, atob, btoa,
      fetch: undefined,
      registerExtension: () => true,
      log: { info() {}, warn() {}, error() {}, debug() {} },
      utils: {
        randomUserAgent: () => "test-agent",
        sha256: () => "hash",
        isDownloadCancelled: () => false,
      },
      file: {},
      URL: require("url").URL,
    },
    extra,
  );
}

// ═══════════════ TIDAL: rotación de access token ═══════════════
console.log("\n=== TIDAL: rotación de access token ===");

const T_MUERTO = "token-muerto-" + "x".repeat(40);
const T_VIVO = "token-vivo-" + "y".repeat(40);
const llamadasTidal = [];

const tidal = cargar(
  RUTA_TIDAL,
  base({
    http: {
      get(url, headers) {
        const auth = String((headers && headers.Authorization) || "");
        llamadasTidal.push(auth.replace("Bearer ", "").slice(0, 10));
        if (auth === "Bearer " + T_VIVO) {
          // Responde con PREVIEW: prueba que la petición SÍ pasó el filtro de auth.
          return {
            statusCode: 200,
            body: JSON.stringify({ assetPresentation: "PREVIEW", manifest: "x" }),
          };
        }
        return {
          statusCode: 401,
          body: '{"status":401,"userMessage":"Token has invalid payload"}',
        };
      },
      post() {
        return { statusCode: 404, body: "{}" };
      },
    },
  }),
);

console.log("\n1) La credencial propia va PRIMERO, sin duplicados");
const ordenTidal = tidal.poolDeTokensTidal({
  tidalAccessToken: T_VIVO,
  tidalTokenPool: T_MUERTO + "\n" + T_VIVO,
});
check(
  "token propio primero y sin duplicados",
  ordenTidal.length === 2 && ordenTidal[0] === T_VIVO,
  ordenTidal.map((t) => t.slice(0, 10)).join(", "),
);

console.log("\n2) Rotación real: token muerto primero -> rota al vivo");
llamadasTidal.length = 0;
tidal.initialize({ tidalTokenPool: T_MUERTO + "\n" + T_VIVO });
let errTidal = null;
try {
  tidal.fetchDirectDownloadInfo("123456", "LOSSLESS");
} catch (e) {
  errTidal = e;
}
check(
  "rotó del token muerto al vivo",
  llamadasTidal.length === 2 &&
    llamadasTidal[0] === T_MUERTO.slice(0, 10) &&
    llamadasTidal[1] === T_VIVO.slice(0, 10),
  llamadasTidal.join(" -> "),
);
check(
  "no se rindió con UNAUTHORIZED",
  !errTidal || errTidal.code !== "UNAUTHORIZED",
  errTidal ? errTidal.code + " / " + errTidal.message.slice(0, 50) : "sin error",
);

console.log("\n3) Con TODOS los tokens muertos se apaga y avisa");
llamadasTidal.length = 0;
tidal.initialize({ tidalTokenPool: T_MUERTO });
let errTodos = null;
try {
  tidal.fetchDirectDownloadInfo("123456", "LOSSLESS");
} catch (e) {
  errTodos = e;
}
check(
  "con todos muertos tira UNAUTHORIZED",
  !!errTodos && errTodos.code === "UNAUTHORIZED",
  errTodos ? errTodos.code : "sin error",
);
check("sin pool directo se apaga", tidal.hasDirectTidalSession() === false);

// ═══════════════ QOBUZ: rotación de cuentas ═══════════════
console.log("\n=== QOBUZ: rotación de cuentas ===");

const BUENA = "buena@correo.com";
const MALA = "mala@correo.com";
const llamadasQobuz = [];

const qobuz = cargar(
  RUTA_QOBUZ,
  base({
    http: {
      post(url, body) {
        const datos = JSON.parse(body || "{}");
        llamadasQobuz.push(datos.email);
        if (datos.email === BUENA && datos.password === "claveBuena") {
          return { statusCode: 200, body: JSON.stringify({ user_auth_token: "TOKEN_OK" }) };
        }
        return {
          statusCode: 401,
          body: '{"status":"error","code":401,"message":"Invalid username/email and password combination"}',
        };
      },
      get() {
        return { statusCode: 404, body: "{}" };
      },
    },
  }),
);

console.log("\n1) La cuenta propia va PRIMERO, sin duplicados");
const ordenQobuz = qobuz.poolDeCuentasQobuz({
  email: BUENA,
  password: "claveBuena",
  qobuzPool: MALA + ":claveMala\n" + BUENA + ":claveBuena",
});
check(
  "cuenta propia primero y sin duplicados",
  ordenQobuz.length === 2 && ordenQobuz[0] === BUENA + ":claveBuena",
  ordenQobuz.join(" | "),
);

console.log("\n2) Rotación real: cuenta mala primero -> rota a la buena");
llamadasQobuz.length = 0;
qobuz.initialize({ qobuzPool: MALA + ":claveMala\n" + BUENA + ":claveBuena" });
let token = null;
let errQobuz = null;
try {
  token = qobuz.qobuzDirectLogin();
} catch (e) {
  errQobuz = e;
}
check(
  "rotó de la cuenta mala a la buena",
  llamadasQobuz.length === 2 && llamadasQobuz[0] === MALA && llamadasQobuz[1] === BUENA,
  llamadasQobuz.join(" -> "),
);
check(
  "consiguió el token",
  token === "TOKEN_OK",
  String(token) + (errQobuz ? " err=" + errQobuz.message : ""),
);

console.log("\n3) Con TODAS las cuentas malas falla claro");
llamadasQobuz.length = 0;
qobuz.initialize({ qobuzPool: MALA + ":claveMala" });
let errTodas = null;
try {
  qobuz.qobuzDirectLogin();
} catch (e) {
  errTodas = e;
}
check(
  "con todas malas tira UNAUTHORIZED",
  !!errTodas && errTodas.code === "UNAUTHORIZED",
  errTodas ? errTodas.code : "sin error",
);

if (fallos) console.log("\n" + fallos + " FALLA(S)");
process.exit(fallos === 0 ? 0 : 1);
