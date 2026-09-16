// pruebas_ytmusic_clientes.js — verifica la MEMORIA de clientes InnerTube de la
// extensión ytmusic-spotiflac (el "ganador pegado") sin compilar la app.
//
// POR QUÉ EXISTE
// La cadena de clientes arranca siempre por el mismo cliente (INNERTUBE_CLIENTS).
// En una IP marcada ese es justo el que YouTube rechaza, así que cada canción
// volvía a pagar la caminata completa (hasta 9 POST + sus sondas de rango)
// aunque un cliente hubiera resuelto audio dos segundos antes con la MISMA
// huella. El ganador pegado arregla eso, pero se rompe fácil: un reordenamiento
// de la lista, una comparación de clase invertida o un early-return lo apagan
// en silencio, y el síntoma en el dispositivo ("YouTube tarda cada vez más") no
// parece un problema de código.
//
// Verifica:
//   1. el ganador se RECUERDA de verdad tras un resolve real (visionos falla
//      403 y tv_embedded sirve): _lastClientOk queda en tv_embedded
//   2. ese ganador pasa AL FRENTE del orden en la canción siguiente
//   3. un ganador marcado como bloqueado NO se sube (no se paga su timeout)
//   4. NO se cambia de clase por latencia: con proveedor de PO Token sano, un
//      ganador anónimo no adelanta a los clientes que traen audio-only (si no,
//      se sirve itag=18 ~128k aunque hubiera 251 opus)
//   5. dentro de su clase, el ganador con token (ios) sí pasa al frente
//   6. nunca se pierde ni se duplica un cliente
//
// Uso (desde la raíz del repo):
//   node scripts/pruebas/extensiones/ytmusic_clientes.js
//
// Se conecta con: assets/extensions/ytmusic-spotiflac/index.js (extensión) y
// go_backend/internal/bundled_extensions/ytmusic-spotiflac/index.js (la copia
// embebida, que debe ser idéntica).

const fs = require("fs");
const vm = require("vm");
const path = require("path");

const ruta =
  process.argv[2] ||
  path.join(
    __dirname,
    "..",
    "..",
    "..",
    "assets",
    "extensions",
    "ytmusic-spotiflac",
    "index.js",
  );

let fallos = 0;
function check(nombre, cond, detalle) {
  if (cond) {
    console.log("  ok    " + nombre);
  } else {
    fallos++;
    console.log("  FALLA " + nombre + (detalle ? "  -> " + detalle : ""));
  }
}

// Sandbox tipo goja: solo se stubea registerExtension, log y fetch.
function cargar(fetchImpl) {
  const source = fs.readFileSync(ruta, "utf8");
  const llamadas = [];
  const avisos = [];
  const sandbox = {
    console: { log() {}, warn() {}, error() {} },
    log: {
      debug() {},
      info() {},
      warn: (...a) => avisos.push(a.join(" ")),
      error: (...a) => avisos.push(a.join(" ")),
    },
    URL,
    Map,
    Set,
    Date,
    Math,
    JSON,
    Number,
    String,
    Boolean,
    Array,
    Object,
    RegExp,
    Error,
    isNaN,
    parseInt,
    parseFloat,
    setTimeout,
    clearTimeout,
    fetch: function (url, opts) {
      llamadas.push({ url: url, opts: opts });
      return fetchImpl(url, opts, llamadas.length);
    },
    registerExtension: function (ext) {
      sandbox.__ext = ext;
    },
  };
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  const hook =
    "\n;globalThis.__t = {" +
    " requestInnerTubeAudioDownload: requestInnerTubeAudioDownload," +
    " clientesInnerTubeEnOrden: clientesInnerTubeEnOrden," +
    " noteInnerTubeClientBlock: noteInnerTubeClientBlock," +
    " innerTubeClientBlocked: innerTubeClientBlocked," +
    " nombresOriginales: INNERTUBE_CLIENTS.map(function (c) { return c.name; })," +
    " get lastClientOk() { return _lastClientOk; }," +
    " setLastClientOk: function (n) { _lastClientOk = n; }," +
    " get CONFIG() { return CONFIG; }," +
    " setTokenMode: function (m) { CONFIG.poTokenMode = m; } };\n";
  vm.runInContext(source + hook, sandbox, { filename: ruta });
  return { sandbox, llamadas, avisos, t: sandbox.__t };
}

// Respuesta de player con un solo audio-only (251 opus, el que se quiere).
function respuestaPlayer(url) {
  return {
    ok: true,
    status: 200,
    json: () => ({
      playabilityStatus: { status: "OK" },
      streamingData: {
        adaptiveFormats: [
          {
            itag: 251,
            mimeType: 'audio/webm; codecs="opus"',
            averageBitrate: 160000,
            url: url,
          },
        ],
      },
    }),
  };
}

// Modelo de YouTube: el cliente [clienteOK] sirve audio; el resto responde 403
// (IP marcada). Las sondas de rango (GET) responden 206 = URL viva.
function modeloIPMarcada(clienteOK) {
  return (url, opts) => {
    const metodo = (opts && opts.method) || "GET";
    if (metodo === "POST") {
      let nombre = "";
      try {
        const body = JSON.parse(opts.body || "{}");
        nombre = body.context.client.clientName;
      } catch (e) {}
      if (nombre === clienteOK) {
        return respuestaPlayer("https://x/251?clen=9999999");
      }
      return { ok: false, status: 403, json: () => ({}) };
    }
    return { ok: true, status: 206, json: () => ({}) };
  };
}

console.log("\n== 1) el ganador se recuerda tras un resolve real ==");
{
  // visionos es el primero del orden estático y acá falla (403); tv_embedded es
  // el que sirve. El resolve tiene que terminar recordándolo.
  const { t, llamadas } = cargar(
    modeloIPMarcada("TVHTML5_SIMPLY_EMBEDDED_PLAYER"),
  );
  t.setTokenMode("off");
  const res = t.requestInnerTubeAudioDownload("VIDEO1", false);
  check(
    "resuelve audio con el cliente que sí contesta",
    !!(res && res.url && Number(res.itag) === 251),
    JSON.stringify(res && { url: res.url, itag: res.itag }),
  );
  check(
    "recuerda al ganador (tv_embedded)",
    t.lastClientOk === "tv_embedded",
    String(t.lastClientOk),
  );
  check(
    "pagó la cadena entera antes del ganador (visionos 403 x2 + tv_embedded post + sonda)",
    llamadas.length === 4,
    "hubo " + llamadas.length,
  );
}

console.log("\n== 2) el ganador pasa al frente en la canción siguiente ==");
{
  const { t } = cargar(modeloIPMarcada("TVHTML5_SIMPLY_EMBEDDED_PLAYER"));
  t.setTokenMode("off");
  t.setLastClientOk("tv_embedded");
  const orden = t.clientesInnerTubeEnOrden().map((c) => c.name);
  check(
    "el ganador es el primero del orden",
    orden[0] === "tv_embedded",
    orden.join(","),
  );
  check(
    "el orden conserva a TODOS los clientes (sin duplicados ni bajas)",
    orden.length === t.nombresOriginales.length &&
      orden.slice().sort().join(",") ===
        t.nombresOriginales.slice().sort().join(","),
    orden.length + " vs " + t.nombresOriginales.length,
  );
}

console.log("\n== 3) un ganador bloqueado no se sube ==");
{
  // Si el mapa de salud ya lo marcó (falló hace minutos), subirlo sería volver a
  // pagar su timeout en cada canción.
  const { t } = cargar(modeloIPMarcada("TVHTML5_SIMPLY_EMBEDDED_PLAYER"));
  t.setTokenMode("off");
  t.setLastClientOk("tv_embedded");
  t.noteInnerTubeClientBlock("tv_embedded", "HTTP 429 rate_limited");
  check(
    "el ganador quedó marcado como bloqueado",
    t.innerTubeClientBlocked("tv_embedded") === true,
  );
  const orden = t.clientesInnerTubeEnOrden().map((c) => c.name);
  check(
    "no se sube un ganador bloqueado",
    orden[0] !== "tv_embedded",
    orden.join(","),
  );
}

console.log("\n== 4) la clase manda: no se cambia por latencia ==");
{
  // Con proveedor de PO Token sano, los clientes que traen audio-only van
  // primero. Un ganador ANÓNIMO no puede adelantarlos: ganaría latencia y
  // perdería calidad (itag=18 ~128k en vez de 251 opus ~160k).
  const { t } = cargar(modeloIPMarcada("TVHTML5_SIMPLY_EMBEDDED_PLAYER"));
  t.setTokenMode("auto");
  t.CONFIG.poTokenProviderURL = "http://127.0.0.1:4416";
  t.setLastClientOk("visionos");
  const orden = t.clientesInnerTubeEnOrden().map((c) => c.name);
  check(
    "el anónimo pegado NO adelanta a los que traen audio-only",
    orden[0] === "android",
    orden.join(","),
  );
  check(
    "el anónimo sigue en la lista (como respaldo)",
    orden.indexOf("visionos") !== -1,
    orden.join(","),
  );
}

console.log(
  "\n== 5) dentro de su clase, el ganador con token sí va primero ==",
);
{
  const { t } = cargar(modeloIPMarcada("TVHTML5_SIMPLY_EMBEDDED_PLAYER"));
  t.setTokenMode("auto");
  t.CONFIG.poTokenProviderURL = "http://127.0.0.1:4416";
  t.setLastClientOk("ios");
  const orden = t.clientesInnerTubeEnOrden().map((c) => c.name);
  check(
    "el ganador con token pasa al frente",
    orden[0] === "ios",
    orden.join(","),
  );
  check(
    "los otros dos con token siguen detrás (android, mweb)",
    orden.slice(1, 3).join(",") === "android,mweb",
    orden.join(","),
  );
}

console.log(
  (fallos === 0 ? "\nTODO OK" : "\n" + fallos + " FALLA(S)") +
    "  (" +
    ruta +
    ")\n",
);
process.exit(fallos === 0 ? 0 : 1);
