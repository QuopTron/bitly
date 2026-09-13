// soundcloud_401.js — verificador del refresh de client_id de la extensión de
// SoundCloud ante un 401. Offline: stubea `http`, `log`, `utils` y
// `registerExtension`, no toca la red.
//
// POR QUÉ EXISTE (el bug que previene)
// La API de SoundCloud responde 401 cuando el client_id scrapeado caduca. La
// extensión refresca el id y reintenta; si el bundle devuelve el MISMO id (pasa
// seguido: la web sirve una variante distinta de la página), el reintento es
// una petición condenada. Peor: la versión vieja dejaba `clientId = null` y
// pedía con `client_id=null`, y ADEMÁS se tragaba el error, así que Go nunca veía
// el 401 y no podía enfriar la fuente. Resultado: ~8 peticiones muertas por
// canción del lote, segundos perdidos por track.
//
// QUÉ VERIFICA
//   modo "mismo"  → el refresh devuelve el MISMO id: debe hacer UNA sola
//                   petición y fallar rápido con un mensaje que contenga
//                   "HTTP 401" (es el marcador que Go usa para el cooldown).
//   modo "nuevo"  → el refresh devuelve un id NUEVO: debe reintentar UNA vez y
//                   funcionar (la ruta buena no se rompió).
//   en ambos      → jamás se pide con client_id nulo/undefined.
//
// Uso: node scripts/pruebas_extensiones/soundcloud_401.js <ruta-index.js> <mismo|nuevo>

const fs = require("fs");
const vm = require("vm");

const ruta = process.argv[2];
const modo = process.argv[3] || "mismo";
if (!ruta) {
  console.error("FALTA la ruta del index.js de soundcloud");
  process.exit(2);
}
const codigo = fs.readFileSync(ruta, "utf8");

const ID_VIEJO = "A".repeat(32);
const ID_NUEVO = "B".repeat(32);

const pedidosApi = [];

const sandbox = {
  log: { info() {}, debug() {}, warn() {}, error() {} },
  utils: { randomUserAgent: () => "UA-de-prueba" },
  registerExtension: (api) => {
    sandbox.__api = api;
  },
  http: {
    get: (url) => {
      if (url.startsWith("https://api-v2.soundcloud.com")) {
        pedidosApi.push(url);
        // La primera llamada siempre rebota; en modo "nuevo" la segunda entra.
        const esReintento = pedidosApi.length > 1;
        if (esReintento && modo === "nuevo") {
          return { statusCode: 200, body: JSON.stringify({ collection: [] }) };
        }
        return { statusCode: 401, body: "{}" };
      }
      if (url.includes("a-v2.sndcdn.com")) {
        // Bundle que "contiene" el client_id que la extensión va a extraer.
        const id = modo === "nuevo" ? ID_NUEVO : ID_VIEJO;
        return { statusCode: 200, body: 'client_id:"' + id + '"' };
      }
      if (url.startsWith("https://soundcloud.com")) {
        return {
          statusCode: 200,
          body:
            '__sc_version="1789138724"' +
            '<script src="https://a-v2.sndcdn.com/assets/55-35992ef2.js"></script>',
        };
      }
      return { statusCode: 404, body: "" };
    },
  },
};

vm.createContext(sandbox);
vm.runInContext(codigo, sandbox);

const api = sandbox.__api;
if (!api) {
  console.error("FALLA: la extensión no registró su API");
  process.exit(1);
}

// Sembramos un client_id "válido" para que la primera llamada lo use.
sandbox.state.clientId = ID_VIEJO;
sandbox.state.clientIdExpiry = Date.now() + 60 * 60 * 1000;

let error = null;
try {
  api.searchTracks("prueba", 5);
} catch (e) {
  error = e;
}

const conNull = pedidosApi.filter(
  (u) => u.includes("client_id=null") || u.includes("client_id=undefined"),
);

const fallos = [];
if (conNull.length > 0) {
  fallos.push("se pidió con client_id nulo: " + conNull[0]);
}

if (modo === "mismo") {
  if (pedidosApi.length !== 1) {
    fallos.push(
      "esperaba 1 sola petición a la API (el id no es renovable), hubo " +
        pedidosApi.length,
    );
  }
  if (!error || !/HTTP 401/.test(error.message)) {
    fallos.push(
      "esperaba un error con HTTP 401, llegó: " + (error ? error.message : "ninguno"),
    );
  }
} else {
  if (pedidosApi.length !== 2) {
    fallos.push("esperaba 2 peticiones (401 + reintento OK), hubo " + pedidosApi.length);
  }
  if (error) {
    fallos.push("no esperaba error con un id nuevo: " + error.message);
  }
}

if (fallos.length) {
  console.log("FALLA [soundcloud " + modo + "]  " + ruta);
  fallos.forEach((f) => console.log("  - " + f));
  process.exit(1);
}
console.log("  ok    soundcloud " + modo + " (peticiones=" + pedidosApi.length + ")");
