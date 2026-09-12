// pruebas_ytmusic_pot.js — verifica el proveedor de PO Token de la extensión
// ytmusic-spotiflac SIN compilar la app.
//
// Por qué existe: YouTube responde "Sign in to confirm you're not a bot" a las
// IPs marcadas (emulador, datacenter) en todos sus clientes InnerTube. La salida
// sin cuenta es un proveedor de PO Token (bgutil, POST /get_pot). El camino se
// rompe fácil y en silencio — un ajuste con default "off", un early-return, un
// contrato de payload equivocado — y el síntoma en el dispositivo es "YouTube
// no encuentra audio", que parece un problema de red y no de código.
//
// Carga la extensión real en un sandbox tipo goja (solo stubea
// registerExtension y fetch), le engancha un hook de test al final del script
// (las funciones internas son declaraciones de primer nivel, así que se pueden
// exponer concatenando código en el MISMO contexto) y verifica:
//   1. normalizePoTokenProviderURL arma bien el endpoint /get_pot
//   2. sin proveedor configurado se prueba PRIMERO el local (bgutil 4416):
//      basta con levantar el contenedor para que YouTube deje de bloquear
//   3. el contrato real de bgutil ({visitor_data} -> {po_token}) se usa de una
//      sola petición, no dos
//   4. mode=off no toca ningún proveedor
//   5. un proveedor caído se enfría: las canciones siguientes NO pagan una
//      conexión fallida cada una
//
// Uso (desde la raíz del repo):
//   node scripts/pruebas_extensiones/ytmusic_pot.js
//   node scripts/pruebas_extensiones/ytmusic_pot.js <ruta-al-index.js>   # p.ej. un mutante
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

// Sandbox con fetch controlado por el test.
function cargar(fetchImpl) {
  const source = fs.readFileSync(ruta, "utf8");
  const llamadas = [];
  const avisos = [];
  const sandbox = {
    console: { log() {}, warn() {}, error() {} },
    // L() solo escribe por el global `log`; lo capturamos para poder afirmar
    // que el aviso de "PO Token obtenido" sale UNA sola vez.
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
    "\n;globalThis.__t = { requestExternalGvsPoToken: requestExternalGvsPoToken," +
    " getGvsPoToken: getGvsPoToken, normalizePoTokenProviderURL: normalizePoTokenProviderURL," +
    " poTokenProviderCandidates: poTokenProviderCandidates, get CONFIG() { return CONFIG; }," +
    " setTokenMode: function (m) { CONFIG.poTokenMode = m; }," +
    " clientesInnerTubeEnOrden: clientesInnerTubeEnOrden," +
    " proveedorPoTokenDisponible: proveedorPoTokenDisponible," +
    " chooseYouTubeFormat: chooseYouTubeFormat," +
    " streamUrlCacheKey: streamUrlCacheKey," +
    " streamUrlCacheGet: streamUrlCacheGet," +
    " streamUrlCacheSet: streamUrlCacheSet," +
    " esFormatoSoloAudio: esFormatoSoloAudio," +
    " nombresClientesOriginales: INNERTUBE_CLIENTS.map(function (c) { return c.name; })," +
    " clientesOriginales: INNERTUBE_CLIENTS," +
    " embedUrlDeclarada: INNERTUBE_EMBED_URL };\n";
  vm.runInContext(source + hook, sandbox, { filename: ruta });
  return { sandbox, llamadas, avisos, t: sandbox.__t, ext: sandbox.__ext };
}

// Cliente InnerTube mínimo, como lo ve la extensión al resolver audio.
function clienteGvs() {
  return {
    name: "WEB",
    requiresGvsPoToken: true,
    body: { context: { client: { clientName: "WEB" } } },
  };
}

// Respuesta del server bgutil 2.x: camelCase (poToken / contentBinding /
// expiresAt). El parser tiene que entenderla tal cual.
function respuestaBgutil(poToken, binding) {
  return {
    ok: true,
    status: 200,
    json: () => ({
      poToken: poToken,
      contentBinding: binding,
      expiresAt: new Date(Date.now() + 6 * 60 * 60 * 1000).toISOString(),
    }),
  };
}

// Modelo FIEL del server real (bgutil 2.x, server/src/main.ts):
//   - `visitor_data` -> 400 "is deprecated, use content_binding instead"
//   - `content_binding` -> 200 { poToken, contentBinding, expiresAt }
// Modelar el rechazo es el punto: si el código manda visitor_data primero,
// acá se ve el 400 y el round-trip extra que costaba.
function serverBgutil2x() {
  return (url, opts, n) => {
    const body = JSON.parse(opts.body || "{}");
    if (body.visitor_data) {
      return {
        ok: false,
        status: 400,
        json: () => ({ error: "visitor_data is deprecated, use content_binding instead" }),
      };
    }
    if (!body.content_binding) {
      return { ok: false, status: 400, json: () => ({ error: "content_binding required" }) };
    }
    return respuestaBgutil("TOKEN_CONTENT_BINDING", body.content_binding);
  };
}

// Proveedor viejo (≤1.x): espera `visitor_data` y responde snake_case.
function serverBgutil1x() {
  return (url, opts) => {
    const body = JSON.parse(opts.body || "{}");
    if (!body.visitor_data) {
      return { ok: false, status: 400, json: () => ({ error: "visitor_data required" }) };
    }
    return {
      ok: true,
      status: 200,
      json: () => ({ po_token: "TOKEN_LEGACY", visit_identifier: body.visitor_data }),
    };
  };
}

console.log("\n== 1) normalizePoTokenProviderURL ==");
{
  const { t } = cargar(() => respuestaBgutil("a", "b"));
  check(
    "base sin path -> /get_pot",
    t.normalizePoTokenProviderURL("http://127.0.0.1:4416") ===
      "http://127.0.0.1:4416/get_pot",
    t.normalizePoTokenProviderURL("http://127.0.0.1:4416"),
  );
  check(
    "con barra final -> /get_pot",
    t.normalizePoTokenProviderURL("https://pot.example.com/") ===
      "https://pot.example.com/get_pot",
  );
  check(
    "ya trae /get_pot -> no se duplica",
    t.normalizePoTokenProviderURL("http://x:4416/get_pot") ===
      "http://x:4416/get_pot",
  );
  check("basura -> vacío", t.normalizePoTokenProviderURL("no es una url") === "");
}

console.log("\n== 2) sin proveedor configurado se prueba el local (bgutil 4416) ==");
{
  const { t, llamadas } = cargar(serverBgutil2x());
  const cands = t.poTokenProviderCandidates();
  check(
    "el primer candidato es el local 4416",
    cands[0] === "http://127.0.0.1:4416/get_pot",
    JSON.stringify(cands),
  );

  check(
    "incluye el alias del emulador (10.0.2.2) para llegar al loopback del PC",
    cands.indexOf("http://10.0.2.2:4416/get_pot") !== -1,
    JSON.stringify(cands),
  );

  const out = t.requestExternalGvsPoToken("VIDEO1", clienteGvs(), "visitor1", false);
  check(
    "devuelve el token del proveedor local",
    !!(out && out.token === "TOKEN_CONTENT_BINDING"),
    JSON.stringify(out),
  );
  check(
    "hizo UNA sola petición (content_binding va primero, sin perder un 400)",
    llamadas.length === 1,
    "hubo " + llamadas.length,
  );
  if (!llamadas.length) {
    check("el body usa content_binding = videoId", false, "no hubo petición");
  } else {
    const body = JSON.parse(llamadas[0].opts.body);
    check(
      "el body usa content_binding = videoId (no visitor_data)",
      body.content_binding === "VIDEO1" && body.visitor_data === undefined,
      JSON.stringify(body),
    );
  }
}

console.log("\n== 2b) proveedor VIEJO (1.x) que solo acepta visitor_data ==");
{
  const { t, llamadas } = cargar(serverBgutil1x());
  const out = t.requestExternalGvsPoToken("VIDEO2", clienteGvs(), "visitor_legacy", false);
  check(
    "cae al 2do payload y igual consigue token",
    !!(out && out.token === "TOKEN_LEGACY"),
    JSON.stringify(out),
  );
  check(
    "probó los dos formatos en el mismo endpoint",
    llamadas.length === 2,
    "hubo " + llamadas.length,
  );
}

console.log("\n== 3) mode=off no consulta ningún proveedor ==");
{
  const { t, llamadas } = cargar(() => respuestaBgutil("TOKEN", "v"));
  t.setTokenMode("off");
  const out = t.getGvsPoToken("VIDEO1", clienteGvs(), "visitor1", false);
  check("devuelve vacío", !out, String(out));
  check("cero peticiones", llamadas.length === 0, "hubo " + llamadas.length);
}

console.log("\n== 4) proveedor caído: se enfría y no reintenta en cada canción ==");
{
  const { t, llamadas } = cargar(() => {
    throw new Error("connect ECONNREFUSED 127.0.0.1:4416");
  });
  t.setTokenMode("auto");
  const candidatos = t.poTokenProviderCandidates().length;
  const uno = t.requestExternalGvsPoToken("V1", clienteGvs(), "vd", false);
  const tras1 = llamadas.length;
  const dos = t.requestExternalGvsPoToken("V2", clienteGvs(), "vd", false);
  const tras2 = llamadas.length;
  const tres = t.requestExternalGvsPoToken("V3", clienteGvs(), "vd", false);
  const tras3 = llamadas.length;
  check("primer intento devuelve vacío", !uno, String(uno));
  check("segundo y tercer intento tampoco inventan token", !dos && !tres);
  check(
    "la 1ra canción prueba a lo sumo los candidatos locales (" + candidatos + ")",
    tras1 <= candidatos,
    "hubo " + tras1,
  );
  check(
    "la 2da canción completa los candidatos, no reinicia la lista",
    tras2 <= candidatos,
    "hubo " + tras2,
  );
  check(
    "a partir de ahí CERO conexiones (todo en cooldown)",
    tras3 === tras2,
    "pasó de " + tras2 + " a " + tras3,
  );
}

console.log("\n== 4b) proveedor SOLO alcanzable por el alias del emulador ==");
{
  // Reproduce el caso real del emulador: el server corre en el PC, así que
  // 127.0.0.1/localhost (dentro del emulador) rechazan la conexión y solo
  // 10.0.2.2 contesta. Sin ese candidato, YouTube queda bloqueado en el emulador.
  const { t, llamadas } = cargar((url) => {
    if (String(url).indexOf("10.0.2.2:4416") === -1) {
      throw new Error("connect ECONNREFUSED " + url);
    }
    return respuestaBgutil("TOKEN_EMULADOR", "vid-emu");
  });
  t.setTokenMode("auto");
  const out = t.requestExternalGvsPoToken("VIDEO_EMU", clienteGvs(), "vd", false);
  check(
    "encuentra el proveedor por el alias del emulador",
    !!(out && out.token === "TOKEN_EMULADOR"),
    JSON.stringify(out),
  );
  check(
    "de la lista de candidatos, el último que contesta es el alias",
    String(llamadas[llamadas.length - 1].url).indexOf("10.0.2.2:4416") !== -1,
    llamadas.map((l) => l.url).join(" -> "),
  );
}

console.log("\n== 5) mode=auto con proveedor sano ==");
{
  const { t, llamadas, avisos } = cargar(serverBgutil2x());
  t.setTokenMode("auto");
  const tok = t.getGvsPoToken("VIDEO9", clienteGvs(), "visitor9", false);
  check("getGvsPoToken devuelve el token", tok === "TOKEN_CONTENT_BINDING", String(tok));
  const segunda = t.getGvsPoToken("VIDEO9", clienteGvs(), "visitor9", false);
  check(
    "el 2do uso sale del caché (sin nueva petición)",
    segunda === "TOKEN_CONTENT_BINDING" && llamadas.length === 1,
    "hubo " + llamadas.length,
  );
  const anuncios = avisos.filter((a) => a.indexOf("[POT] PO Token obtenido") !== -1);
  check(
    "avisa en el log cuando el proveedor entra en juego (visible con logLevel=warn)",
    anuncios.length === 1,
    "avisos=" + anuncios.length,
  );
  t.getGvsPoToken("VIDEO10", clienteGvs(), "visitor10", false);
  check(
    "el aviso no se repite por canción",
    avisos.filter((a) => a.indexOf("[POT] PO Token obtenido") !== -1).length === 1,
    "avisos totales=" + avisos.length,
  );
}

console.log("\n== 6) orden de clientes: solo se priorizan los que dan audio-only si HAY proveedor ==");
{
  // Proveedor caído. Antes de intentar nada no se puede saber que está caído,
  // así que el primer intento va optimista (prioriza los clientes con token) y
  // ESE intento es el que lo marca en cooldown. Lo que importa —y es el
  // invariante que evita degradar la app cuando no hay proveedor— es que a
  // partir de ahí el orden VUELVE solo al clásico: no queda priorizando
  // clientes que no pueden funcionar en cada canción.
  const sinProv = cargar(() => {
    throw new Error("connect ECONNREFUSED");
  });
  sinProv.t.setTokenMode("auto");
  check(
    "proveedor caído: el 1er intento va optimista (no se puede saber antes de probar)",
    sinProv.t.proveedorPoTokenDisponible() === true,
  );

  // Un intento real contra el proveedor caído.
  sinProv.t.requestExternalGvsPoToken("V1", clienteGvs(), "vd", false);

  check(
    "proveedor caído: tras el fallo, proveedorPoTokenDisponible() = false",
    sinProv.t.proveedorPoTokenDisponible() === false,
  );
  const clasico = sinProv.t.clientesInnerTubeEnOrden().map((c) => c.name);
  check(
    "proveedor caído: el orden VUELVE al anónimo (empieza visionos)",
    clasico.join(",") === sinProv.t.nombresClientesOriginales.join(","),
    clasico.join(","),
  );
  check(
    "proveedor caído: el primero es visionos (anónimo sin PO token ni JS player)",
    clasico[0] === "visionos",
    clasico[0],
  );

  // Con proveedor sano: los clientes que exigen token van PRIMERO.
  const conProv = cargar(serverBgutil2x());
  conProv.t.setTokenMode("auto");
  check(
    "con proveedor: proveedorPoTokenDisponible() = true",
    conProv.t.proveedorPoTokenDisponible() === true,
  );
  const orden = conProv.t.clientesInnerTubeEnOrden().map((c) => c.name);
  check(
    "con proveedor: primero android, ios y mweb (los que traen audio-only)",
    orden.slice(0, 3).join(",") === "android,ios,mweb",
    orden.join(","),
  );
  check(
    "con proveedor: los clientes sin token quedan como respaldo (visionos primero)",
    orden.slice(3).join(",") ===
      "android_vr,visionos,tv_embedded,web_embedded,tv,tv_downgraded",
    orden.join(","),
  );
  check(
    "con proveedor: no se pierde ningún cliente",
    orden.length === conProv.t.nombresClientesOriginales.length,
    String(orden.length),
  );

  // mode=off: nunca se prioriza nada, aunque el server esté levantado.
  const apagado = cargar(serverBgutil2x());
  apagado.t.setTokenMode("off");
  check(
    "mode=off: no se prioriza nada aunque el proveedor esté vivo",
    apagado.t.clientesInnerTubeEnOrden().map((c) => c.name).join(",") ===
      apagado.t.nombresClientesOriginales.join(","),
  );
}

console.log("\n== 6b) los trucos de clientes anónimos (lo que hace yt-dlp) ==");
{
  const { t } = cargar(serverBgutil2x());
  const porNombre = {};
  t.clientesOriginales.forEach((c) => (porNombre[c.name] = c));

  // 1) visionos: sin PO Token Y sin JS player. Es EL ancla anónima: devuelve
  //    URLs directas de audio solo-audio sin cuenta y sin proveedor externo.
  check("existe el cliente visionos", !!porNombre.visionos);
  check(
    "visionos no exige PO Token ni JS player",
    !!porNombre.visionos && porNombre.visionos.requiresGvsPoToken === false,
  );
  check(
    "visionos se declara como VISIONOS con su versión de yt-dlp",
    porNombre.visionos &&
      porNombre.visionos.body.context.client.clientName === "VISIONOS" &&
      porNombre.visionos.body.context.client.clientVersion === "1.02",
    JSON.stringify(porNombre.visionos && porNombre.visionos.body),
  );
  check(
    "visionos va ANTES que cualquier cliente con token",
    t.nombresClientesOriginales.indexOf("visionos") === 0,
    t.nombresClientesOriginales.join(","),
  );

  // 2) Clientes embebidos: el embedUrl NO puede ser de YouTube. Un embedUrl
  //    de youtube.com hace que YouTube trate el pedido como no-incrustable y
  //    lo rechace; con un sitio tercero válido pasa como embed legítimo.
  check(
    "el embedUrl declarado por los clientes embebidos no es de YouTube",
    t.embedUrlDeclarada.indexOf("youtube.com") === -1,
    t.embedUrlDeclarada,
  );
  ["tv_embedded", "web_embedded"].forEach((n) => {
    const emb = porNombre[n] && porNombre[n].body.context.thirdParty;
    check(
      "" + n + " usa un embedUrl tercero (no youtube.com)",
      !!emb && String(emb.embedUrl).indexOf("youtube.com") === -1,
      JSON.stringify(emb),
    );
  });

  // 3) tv y tv_downgraded: la vía estable sin token (requiere descifrar firma,
  //    que la extensión hace con solveYouTubePlayerChallenge).
  check(
    "existe tv_downgraded (variante TV con versión 5.x)",
    !!porNombre.tv_downgraded &&
      porNombre.tv_downgraded.body.context.client.clientVersion === "5.20260707",
    JSON.stringify(porNombre.tv_downgraded && porNombre.tv_downgraded.body),
  );
  check(
    "tv y tv_downgraded usan el UA de Cobalt, no un Tizen falso",
    porNombre.tv.ua.indexOf("Cobalt") !== -1 &&
      porNombre.tv_downgraded.ua.indexOf("Cobalt") !== -1,
    porNombre.tv.ua + " | " + porNombre.tv_downgraded.ua,
  );

  // 4) android_vr sigue existiendo (con proveedor sirve en IPs limpias) pero
  //    ya no es el ancla: YouTube 403ea todos sus formatos con 1.65.10.
  check(
    "android_vr sigue en la cadena como respaldo con token",
    !!porNombre.android_vr && porNombre.android_vr.requiresGvsPoToken === true,
  );
  check(
    "siguen estando los clientes móviles que dan audio-only con token",
    !!porNombre.android && !!porNombre.ios && !!porNombre.mweb &&
      porNombre.android.requiresGvsPoToken &&
      porNombre.ios.requiresGvsPoToken &&
      porNombre.mweb.requiresGvsPoToken,
  );
}

console.log("\n== 7) la consecuencia en la calidad: audio-only vs itag=18 ==");
{
  const { t } = cargar(serverBgutil2x());
  // Formatos como los que devuelve InnerTube: 251 opus ~160k y 18 muxed ~96k.
  const fmt251 = {
    itag: 251,
    mimeType: 'audio/webm; codecs="opus"',
    averageBitrate: 160000,
    url: "https://x/251",
  };
  const fmt140 = {
    itag: 140,
    mimeType: 'audio/mp4; codecs="mp4a.40.2"',
    averageBitrate: 128000,
    url: "https://x/140",
  };
  const fmt18 = {
    itag: 18,
    mimeType: 'video/mp4; codecs="avc1"',
    averageBitrate: 96000,
    url: "https://x/18",
  };
  const formatos = [fmt18, fmt140, fmt251];
  const clienteToken = { name: "android", requiresGvsPoToken: true };
  const clienteSeguro = { name: "tv_embedded", requiresGvsPoToken: false };

  check(
    "cliente CON token y token en mano: elige 251 (audio-only, mejor bitrate)",
    Number((t.chooseYouTubeFormat(formatos, clienteToken, true) || {}).itag) === 251,
    String((t.chooseYouTubeFormat(formatos, clienteToken, true) || {}).itag),
  );
  // Este es el síntoma que se veía: sin token, al cliente que exige token se le
  // descartan los audio-only y solo le queda itag=18.
  check(
    "cliente CON token y SIN token: cae a itag=18 (el síntoma)",
    Number((t.chooseYouTubeFormat(formatos, clienteToken, false) || {}).itag) === 18,
    String((t.chooseYouTubeFormat(formatos, clienteToken, false) || {}).itag),
  );
  check(
    "cliente que NO exige token: elige 251 igual (no lo bloquea el token)",
    Number((t.chooseYouTubeFormat(formatos, clienteSeguro, false) || {}).itag) === 251,
    String((t.chooseYouTubeFormat(formatos, clienteSeguro, false) || {}).itag),
  );
}

console.log("\n== 8) rutas separadas: el audio nunca reusa la URL del video ==");
{
  // El resolvedor de audio y el del visualizador comparten método y comparten
  // map de caché. Con la clave atada sólo al video, resolver el visualizador
  // (itag=18, video+audio) dejaba la entrada del AUDIO apuntando al muxed: se
  // oía YouTube a ~128 kbps aunque hubiera PO token y formatos solo-audio.
  const audio251 = {
    url: "https://x/251",
    itag: 251,
    mimeType: 'audio/webm; codecs="opus"',
  };
  const video18 = { url: "https://x/18", itag: 18, mimeType: 'video/mp4; codecs="avc1"' };
  // El fallback de "misma respuesta" reusa el mimeType del formato original
  // aunque la URL sea la del 18 — se distingue por el itag, no por el mime.
  const video18ConMimeAudio = {
    url: "https://x/18",
    itag: 18,
    mimeType: 'audio/webm; codecs="opus"',
  };

  const { t } = cargar(serverBgutil2x());
  t.setTokenMode("auto");

  check(
    "la clave de audio y la de video son distintas para el mismo video",
    t.streamUrlCacheKey("V1", false) !== t.streamUrlCacheKey("V1", true),
    t.streamUrlCacheKey("V1", false) + " vs " + t.streamUrlCacheKey("V1", true),
  );

  // El caso que producía el síntoma: el visualizador resuelve y cachea un 18.
  t.streamUrlCacheSet("V1", video18, true);
  check(
    "resolver el visualizador NO envenena la ruta de audio",
    t.streamUrlCacheGet("V1", false) === null,
    JSON.stringify(t.streamUrlCacheGet("V1", false)),
  );
  check(
    "el video sí reusa su propia entrada",
    (t.streamUrlCacheGet("V1", true) || {}).itag === 18,
    JSON.stringify(t.streamUrlCacheGet("V1", true)),
  );

  // Y al revés: el audio no le sirve al visualizador (no tiene cuadros).
  t.streamUrlCacheSet("V2", audio251, false);
  check(
    "el audio se reusa en la ruta de audio",
    (t.streamUrlCacheGet("V2", false) || {}).itag === 251,
    JSON.stringify(t.streamUrlCacheGet("V2", false)),
  );
  check(
    "una URL solo-audio no le sirve al visualizador",
    t.streamUrlCacheGet("V2", true) === null,
    JSON.stringify(t.streamUrlCacheGet("V2", true)),
  );

  check(
    "itag=18 es degradado aunque su mime diga audio/*",
    t.esFormatoSoloAudio(video18ConMimeAudio) === false,
  );
  check("itag=251 es solo-audio", t.esFormatoSoloAudio(audio251) === true);

  // Entrada degradada + proveedor disponible: se descarta para intentar el
  // formato bueno, y se recuerda el intento para no pagar la cadena cada vez.
  t.streamUrlCacheSet("V3", video18, false);
  check(
    "degradada + proveedor: la primera lectura se descarta (intenta el solo-audio)",
    t.streamUrlCacheGet("V3", false) === null,
    JSON.stringify(t.streamUrlCacheGet("V3", false)),
  );
  check(
    "degradada + proveedor: tras el intento sirve la cacheada (no repite la cadena)",
    (t.streamUrlCacheGet("V3", false) || {}).itag === 18,
    JSON.stringify(t.streamUrlCacheGet("V3", false)),
  );

  // Sin proveedor no hay nada mejor que buscar: se sirve la cacheada tal cual
  // (replay rápido, que es el motivo de que esta caché exista).
  const apagado = cargar(() => respuestaBgutil("TOKEN", "v"));
  apagado.t.setTokenMode("off");
  apagado.t.streamUrlCacheSet("V4", video18, false);
  check(
    "degradada sin proveedor: se sirve la cacheada (replay rápido)",
    (apagado.t.streamUrlCacheGet("V4", false) || {}).itag === 18,
    JSON.stringify(apagado.t.streamUrlCacheGet("V4", false)),
  );
  // Sin proveedor no hay regla de degradada que tape el envenenamiento: si las
  // claves fueran compartidas, acá se vería el itag=18 del visualizador en la
  // ruta de audio (el síntoma exacto, sin depender del proveedor).
  apagado.t.streamUrlCacheSet("V5", video18, true);
  check(
    "sin proveedor: el visualizador tampoco envenena el audio",
    apagado.t.streamUrlCacheGet("V5", false) === null,
    JSON.stringify(apagado.t.streamUrlCacheGet("V5", false)),
  );
}

console.log(
  (fallos === 0 ? "\nTODO OK" : "\n" + fallos + " FALLA(S)") + "  (" + ruta + ")\n",
);
process.exit(fallos === 0 ? 0 : 1);
