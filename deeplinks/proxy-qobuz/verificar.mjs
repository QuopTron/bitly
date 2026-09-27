// verificar.mjs — prueba el Worker SIN desplegarlo.
//
// Por qué existe: el Worker firma peticiones a Qobuz con MD5 hecho a mano. Un
// error ahí no rompe nada visible — la API simplemente devuelve 401 y el canal
// queda mudo. Acá se comprueba contra un vector calculado FUERA del proyecto
// (con hashlib de Python) y contra el contrato que espera la app.
//
// Uso: node deeplinks/proxy-qobuz/verificar.mjs

import { md5Hex, firmaQobuz, reiniciarCacheClavesVivas } from "./worker.js";

let fallos = 0;
function check(nombre, ok, detalle) {
  if (ok) console.log("  ok    " + nombre);
  else {
    fallos++;
    console.log("  FALLA " + nombre + (detalle ? "  -> " + detalle : ""));
  }
}

console.log("\n== 1) MD5 (implementado a mano) contra vectores conocidos ==");
check("md5('')", md5Hex("") === "d41d8cd98f00b204e9800998ecf8427e", md5Hex(""));
check("md5('abc')", md5Hex("abc") === "900150983cd24fb0d6963f7d28e17f72", md5Hex("abc"));
check(
  "md5(vector de la firma)",
  md5Hex("trackgetFileUrlformat_id5intentstreamtrack_id123451700000000s3cr3t") ===
    "16dfa3f6c0f51d356b3691170920487b",
  md5Hex("trackgetFileUrlformat_id5intentstreamtrack_id123451700000000s3cr3t"),
);

console.log("\n== 2) firmaQobuz contra el MISMO vector que el backend Go ==");
check(
  "getFileUrl",
  firmaQobuz("track/getFileUrl", { format_id: "5", intent: "stream", track_id: "12345" }, "1700000000", "s3cr3t") ===
    "16dfa3f6c0f51d356b3691170920487b",
);
check(
  "catalog/search",
  firmaQobuz("catalog/search", { query: "USUM72500857", limit: "5", offset: "0" }, "1700000000", "s3cr3t") ===
    "1a34fe5c139084ffb44a0ac11d90c832",
);

console.log("\n== 3) contrato del endpoint /keys ==");
{
  const { default: worker } = await import("./worker.js");
  // Los tests son OFFLINE: la fuente viva (flacdownloader) no se toca. Con el
  // stub fallando se prueba el respaldo a los secretos del Worker.
  const original = globalThis.fetch;
  globalThis.fetch = async (url, opts) => {
    if (/\/api\/qobuz\/keys/.test(String(url))) throw new Error("fuente viva caída (stub)");
    return original(url, opts);
  };
  reiniciarCacheClavesVivas();

  const respuesta = await worker.fetch(new Request("https://proxy.test/keys"), {
    QOBUZ_APP_ID: "APP1",
    QOBUZ_APP_SECRET: "SECRETO1",
  });
  const cuerpo = await respuesta.json();
  check("/keys responde 200", respuesta.status === 200, String(respuesta.status));
  check("devuelve appId+appSecret (lo que la app espera)", cuerpo.appId === "APP1" && cuerpo.appSecret === "SECRETO1", JSON.stringify(cuerpo));
  check("se cachea 5 min (no se golpea el Worker por canción)", (respuesta.headers.get("cache-control") || "").includes("300"));

  // Cache frío: sin secretos Y sin fuente viva, tiene que avisar.
  reiniciarCacheClavesVivas();
  const sinClaves = await worker.fetch(new Request("https://proxy.test/keys"), {});
  check("sin claves configuradas avisa con 500 en vez de mentir", sinClaves.status === 500, String(sinClaves.status));
  globalThis.fetch = original;
}

console.log("\n== 3b) /keys trae las claves EN VIVO (la rotación se cura sola) ==");
{
  const { default: worker } = await import("./worker.js");
  const original = globalThis.fetch;
  const env = { QOBUZ_APP_ID: "VIEJO1", QOBUZ_APP_SECRET: "VIEJO2" };

  let pedida = "";
  let salidas = 0;
  globalThis.fetch = async (url) => {
    if (/\/api\/qobuz\/keys/.test(String(url))) {
      pedida = String(url);
      salidas++;
      return new Response('{"appId":"VIVO1","appSecret":"VIVO2"}', {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    throw new Error("fetch inesperado: " + url);
  };
  reiniciarCacheClavesVivas();

  const viva = await worker.fetch(new Request("https://proxy.test/keys"), env);
  const cuerpoViva = await viva.json();
  check("toca la fuente viva de claves", /flacdownloader\.com\/api\/qobuz\/keys/.test(pedida), pedida);
  check("devuelve la clave VIVA, no la del secreto", cuerpoViva.appId === "VIVO1" && cuerpoViva.appSecret === "VIVO2", JSON.stringify(cuerpoViva));

  // La segunda petición sale del cache: la fuente se toca UNA vez, no por canción.
  const repetida = await worker.fetch(new Request("https://proxy.test/keys"), env);
  check("la segunda petición sale del cache (no golpea la fuente)", salidas === 1, String(salidas));
  check("y devuelve lo mismo", (await repetida.json()).appId === "VIVO1");

  // Fuente que responde basura → respaldo de los secretos (no rompe el canal).
  globalThis.fetch = async () => new Response('{"nada":true}', { status: 200 });
  reiniciarCacheClavesVivas();
  const basura = await worker.fetch(new Request("https://proxy.test/keys"), env);
  const cuerpoBasura = await basura.json();
  check("fuente inválida → cae al secreto del Worker", cuerpoBasura.appId === "VIEJO1" && cuerpoBasura.appSecret === "VIEJO2", JSON.stringify(cuerpoBasura));

  // QOBUZ_LIVE_KEYS_URL="" apaga la fuente viva: foto fija de los secretos.
  globalThis.fetch = async () => { throw new Error("no debería tocarse la fuente"); };
  reiniciarCacheClavesVivas();
  const apagada = await worker.fetch(new Request("https://proxy.test/keys"), { ...env, QOBUZ_LIVE_KEYS_URL: "" });
  check('QOBUZ_LIVE_KEYS_URL="" vuelve a la foto fija', (await apagada.json()).appId === "VIEJO1");

  // Y si la fuente está caída y NO hay secretos, avisa en vez de mentir.
  reiniciarCacheClavesVivas();
  const sinNada = await worker.fetch(new Request("https://proxy.test/keys"), {});
  check("sin fuente viva y sin secretos avisa con 500", sinNada.status === 500, String(sinNada.status));

  globalThis.fetch = original;
}

console.log("\n== 3c) el relay se cura solo si Qobuz rechaza las claves (400/401) ==");
{
  const { default: worker } = await import("./worker.js");
  const original = globalThis.fetch;
  let clavesFuente = 0;
  const firmas = [];
  globalThis.fetch = async (url) => {
    const u = String(url);
    if (/\/api\/qobuz\/keys/.test(u)) {
      clavesFuente++;
      const appId = clavesFuente === 1 ? "VIEJO" : "NUEVO";
      return new Response(JSON.stringify({ appId, appSecret: "S" + appId }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    firmas.push(u);
    // La primera firma usa la clave vieja → Qobuz contesta 401 (rotación);
    // con la recién recargada, 200.
    return u.includes("app_id=VIEJO")
      ? new Response('{"error":"bad app_id"}', { status: 401 })
      : new Response('{"ok":true}', { status: 200, headers: { "content-type": "application/json" } });
  };
  reiniciarCacheClavesVivas();

  const respuesta = await worker.fetch(
    new Request("https://proxy.test/api.json/0.2/catalog/search?query=x"),
    { QOBUZ_APP_ID: "RESPALDO", QOBUZ_APP_SECRET: "RESPALDO" },
  );
  globalThis.fetch = original;
  check("reintenta una vez tras el 401", firmas.length === 2, String(firmas.length));
  check("el reintento usa la clave recién recargada", !!(firmas[1] && firmas[1].includes("app_id=NUEVO")), firmas[1] || "");
  check("devuelve la respuesta buena", respuesta.status === 200, String(respuesta.status));
}

console.log("\n== 4) el relay NO deja que el app_secret salga del Worker ==");
{
  const { default: worker } = await import("./worker.js");
  const original = globalThis.fetch;
  let visto = null;
  globalThis.fetch = async (url, opts) => {
    // La fuente viva falla (stub offline): el relay firma con los secretos.
    if (/\/api\/qobuz\/keys/.test(String(url))) throw new Error("fuente viva caída (stub)");
    visto = { url: String(url), headers: opts && opts.headers };
    return new Response('{"url":"https://cdn.qobuz.example/x.flac"}', {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  };
  reiniciarCacheClavesVivas();
  const respuesta = await worker.fetch(
    new Request("https://proxy.test/api.json/0.2/track/getFileUrl?format_id=6&intent=stream&track_id=312055179"),
    { QOBUZ_APP_ID: "APP1", QOBUZ_APP_SECRET: "SECRETO1", QOBUZ_USER_TOKEN: "TOKEN_USUARIO" },
  );
  const cuerpo = await respuesta.json();
  check("reenvía a la API de Qobuz", !!(visto && visto.url.startsWith("https://www.qobuz.com/api.json/0.2/track/getFileUrl")), visto ? visto.url : "sin fetch");
  check(
    "agrega app_id + request_ts + request_sig",
    !!(visto && /app_id=APP1/.test(visto.url) && /request_sig=[0-9a-f]{32}/.test(visto.url)),
    visto ? visto.url : "",
  );
  check("el token de usuario va por CABECERA (no rompe la firma)", visto && visto.headers["X-User-Auth-Token"] === "TOKEN_USUARIO");

  // Y si el Worker NO tiene token propio, tiene que REENVIAR el de quien llama:
  // si lo pisara, apuntar la app a este Worker le costaría la sesión a cada
  // usuario (y con ella el FLAC de su suscripción).
  await worker.fetch(
    new Request("https://proxy.test/api.json/0.2/track/getFileUrl?format_id=6&intent=stream&track_id=312055179", {
      headers: { "X-User-Auth-Token": "TOKEN_DEL_USUARIO" },
    }),
    { QOBUZ_APP_ID: "APP1", QOBUZ_APP_SECRET: "SECRETO1" },
  );
  check(
    "sin token propio reenvía el X-User-Auth-Token de quien llama",
    !!(visto && visto.headers["X-User-Auth-Token"] === "TOKEN_DEL_USUARIO"),
    visto ? JSON.stringify(visto.headers) : "sin fetch",
  );
  globalThis.fetch = original;

  check("devuelve el JSON de Qobuz tal cual", cuerpo.url === "https://cdn.qobuz.example/x.flac", JSON.stringify(cuerpo));
  check("no-store: la URL de la CDN no se cachea", (respuesta.headers.get("cache-control") || "").includes("no-store"));
}

console.log("\n== 4b) QOBUZ_RELAY_SECRET: /keys y el relay NO quedan abiertos ==");
{
  const { default: worker } = await import("./worker.js");
  const env = {
    QOBUZ_APP_ID: "APP1",
    QOBUZ_APP_SECRET: "SECRETO1",
    QOBUZ_RELAY_SECRET: "s3cr3to",
    QOBUZ_AUTH_TOKENS: "TOKEN_UNO_1234567890",
  };

  // La fuente viva falla (stub): se prueba el respaldo sin salir a la red.
  const original = globalThis.fetch;
  globalThis.fetch = async (url, opts) => {
    if (/\/api\/qobuz\/keys/.test(String(url))) throw new Error("fuente viva caída (stub)");
    return original(url, opts);
  };
  reiniciarCacheClavesVivas();

  const sinPrefijo = await worker.fetch(new Request("https://proxy.test/keys"), env);
  check("/keys sin el secreto responde 403", sinPrefijo.status === 403, String(sinPrefijo.status));

  const conPrefijo = await worker.fetch(new Request("https://proxy.test/s3cr3to/keys"), env);
  const claves = conPrefijo.status === 200 ? await conPrefijo.json() : {};
  check("/keys con el secreto responde 200", conPrefijo.status === 200, String(conPrefijo.status));
  check("y sigue devolviendo el par", claves.appId === "APP1" && claves.appSecret === "SECRETO1", JSON.stringify(claves));

  // El relay: mismo trato, y el prefijo NO puede llegar a Qobuz.
  let visto = null;
  globalThis.fetch = async (u) => {
    if (/\/api\/qobuz\/keys/.test(String(u))) throw new Error("fuente viva caída (stub)");
    visto = { url: String(u) };
    return new Response("{}", { status: 200, headers: { "content-type": "application/json" } });
  };
  const relaySin = await worker.fetch(new Request("https://proxy.test/api.json/0.2/catalog/search?query=x"), env);
  check("el relay sin el secreto responde 403", relaySin.status === 403, String(relaySin.status));

  const relayCon = await worker.fetch(new Request("https://proxy.test/s3cr3to/api.json/0.2/catalog/search?query=x"), env);
  check("el relay con el secreto responde 200", relayCon.status === 200, String(relayCon.status));
  check(
    "el prefijo se quita y no viaja a Qobuz",
    !!(visto && visto.url.startsWith("https://www.qobuz.com/api.json/0.2/catalog/search") && !visto.url.includes("s3cr3to")),
    visto ? visto.url : "sin fetch",
  );

  // El /pool tiene su propio secreto: NO queda detrás del del relay.
  const pool = await worker.fetch(new Request("https://proxy.test/pool"), env);
  check("/pool no queda detrás del secreto del relay", pool.status === 200, String(pool.status));

  // Sin QOBUZ_RELAY_SECRET, todo sigue abierto (compatibilidad).
  const abierto = await worker.fetch(new Request("https://proxy.test/keys"), {
    QOBUZ_APP_ID: "APP1", QOBUZ_APP_SECRET: "SECRETO1",
  });
  check("sin QOBUZ_RELAY_SECRET, /keys sigue abierto", abierto.status === 200, String(abierto.status));

  // Rate limiting por IP: con el binding, el que se pasa recibe 429 en vez de
  // comerse la cuota diaria de todos.
  const limitador = { limit: async ({ key }) => ({ success: !key.startsWith("9.9.9.9") }) };
  const dentro = await worker.fetch(
    new Request("https://proxy.test/s3cr3to/keys", { headers: { "CF-Connecting-IP": "1.2.3.4" } }),
    { ...env, LIMITADOR: limitador },
  );
  check("una IP dentro del límite pasa", dentro.status === 200, String(dentro.status));
  const fuera = await worker.fetch(
    new Request("https://proxy.test/s3cr3to/keys", { headers: { "CF-Connecting-IP": "9.9.9.9" } }),
    { ...env, LIMITADOR: limitador },
  );
  check("una IP pasada de rosca recibe 429", fuera.status === 429, String(fuera.status));
  const poolSinLimite = await worker.fetch(new Request("https://proxy.test/pool"), { ...env, LIMITADOR: limitador });
  check("/pool no pasa por el limitador (la app lo baja al arrancar)", poolSinLimite.status === 200, String(poolSinLimite.status));

  globalThis.fetch = original;
}

console.log("\n== 4c) cache del edge en el search (no gasta cuota en repetidas) ==");
{
  const { default: worker } = await import("./worker.js");
  const memoria = new Map();
  globalThis.caches = {
    default: {
      match: async (req) => memoria.get(req.url) || undefined,
      put: async (req, res) => {
        memoria.set(req.url, res);
      },
    },
  };

  const original = globalThis.fetch;
  let llamadas = 0;
  globalThis.fetch = async (url) => {
    // La fuente viva no cuenta como llamada a Qobuz: el cache del search mide
    // cuántas veces se repite la consulta contra Qobuz, no contra el origen de
    // claves.
    if (/\/api\/qobuz\/keys/.test(String(url))) throw new Error("fuente viva caída (stub)");
    llamadas++;
    return new Response('{"x":1}', { status: 200, headers: { "content-type": "application/json" } });
  };
  reiniciarCacheClavesVivas();

  const env = { QOBUZ_APP_ID: "APP1", QOBUZ_APP_SECRET: "SECRETO1" };
  const url = "https://proxy.test/api.json/0.2/catalog/search?query=x&limit=1";
  const primera = await worker.fetch(new Request(url), env);
  const repetida = await worker.fetch(new Request(url), env);

  // getFileUrl NO se cachea: su URL de CDN vence en minutos.
  const archivo = "https://proxy.test/api.json/0.2/track/getFileUrl?format_id=6&intent=stream&track_id=1";
  globalThis.fetch = async (url) => {
    if (/\/api\/qobuz\/keys/.test(String(url))) throw new Error("fuente viva caída (stub)");
    llamadas++;
    return new Response('{"url":"https://cdn.qobuz.example/x.flac"}', { status: 200, headers: { "content-type": "application/json" } });
  };
  const archivo1 = await worker.fetch(new Request(archivo), env);
  await worker.fetch(new Request(archivo), env);

  globalThis.fetch = original;
  delete globalThis.caches;

  const textoRepetida = await repetida.text();

  check("la búsqueda se pide UNA vez a Qobuz (la repetida sale del cache)", llamadas === 3, String(llamadas));
  check("y devuelve lo mismo", textoRepetida === '{"x":1}', textoRepetida);
  check("la búsqueda se cachea 60 s", (primera.headers.get("cache-control") || "").includes("60"), primera.headers.get("cache-control"));
  check("getFileUrl NO se cachea (no-store)", (archivo1.headers.get("cache-control") || "").includes("no-store"), archivo1.headers.get("cache-control"));
}

console.log("\n== 5) contrato del endpoint /pool (el pool de sesiones para la app) ==");
{
  const { default: worker } = await import("./worker.js");
  const respuesta = await worker.fetch(new Request("https://proxy.test/pool"), {
    QOBUZ_AUTH_TOKENS: "TOKEN_UNO_1234567890, TOKEN_DOS_0987654321",
  });
  const texto = await respuesta.text();
  const lineas = texto.trim().split("\n");
  check("/pool responde 200", respuesta.status === 200, String(respuesta.status));
  check("es texto plano", (respuesta.headers.get("content-type") || "").startsWith("text/plain"));
  check(
    "una línea 'user_auth_token=<token>' por cuenta (formato que lee el extractor Go)",
    lineas.length === 2 &&
      lineas.every((l) => /^user_auth_token=[A-Za-z0-9._~+/=-]{16,}$/.test(l)),
    JSON.stringify(lineas),
  );
  check("recorta la coma y el espacio de QOBUZ_AUTH_TOKENS", lineas[1] === "user_auth_token=TOKEN_DOS_0987654321", lineas[1]);
  check("no-store: si rotás un token, la próxima bajada lo ve", (respuesta.headers.get("cache-control") || "").includes("no-store"));

  const vacio = await worker.fetch(new Request("https://proxy.test/pool"), {});
  const cuerpoVacio = await vacio.text();
  check("sin tokens avisa con 503 en vez de mentir", vacio.status === 503, String(vacio.status));
  check("el 503 dice 'token' (la app lo lee y pausa la fuente con backoff)", /token/i.test(cuerpoVacio), cuerpoVacio);
}

console.log("\n== 6) /pool con QOBUZ_POOL_SECRET: los tokens no quedan públicos ==");
{
  const { default: worker } = await import("./worker.js");
  const env = { QOBUZ_AUTH_TOKENS: "TOKEN_UNO_1234567890", QOBUZ_POOL_SECRET: "S3CRET0" };

  const sinSecreto = await worker.fetch(new Request("https://proxy.test/pool"), env);
  check("sin secreto responde 403", sinSecreto.status === 403, String(sinSecreto.status));
  check(
    "403 por defecto (no filtra si hay tokens)",
    !(await sinSecreto.text()).includes("TOKEN_UNO"),
  );

  const malo = await worker.fetch(new Request("https://proxy.test/pool/NO-ES"), env);
  check("secreto equivocado responde 403", malo.status === 403, String(malo.status));

  const porRuta = await worker.fetch(new Request("https://proxy.test/pool/S3CRET0"), env);
  const cuerpoRuta = await porRuta.text();
  check("secreto en la ruta responde 200", porRuta.status === 200, String(porRuta.status));
  check(
    "y devuelve el token",
    cuerpoRuta.trim() === "user_auth_token=TOKEN_UNO_1234567890",
    cuerpoRuta.trim(),
  );

  const porQuery = await worker.fetch(new Request("https://proxy.test/pool?s=S3CRET0"), env);
  check("secreto en ?s= también responde 200", porQuery.status === 200, String(porQuery.status));

  // Sin secreto configurado, /pool queda abierto (compatibilidad).
  const abierto = await worker.fetch(new Request("https://proxy.test/pool"), {
    QOBUZ_AUTH_TOKENS: "TOKEN_UNO_1234567890",
  });
  check("sin QOBUZ_POOL_SECRET configurado, /pool sigue abierto", abierto.status === 200, String(abierto.status));
}

console.log(fallos === 0 ? "\nTODO OK\n" : "\n" + fallos + " FALLA(S)\n");
process.exit(fallos === 0 ? 0 : 1);
