// ─────────────────────────────────────────────────────────────
// worker.js — Proxy propio de Qobuz (Cloudflare Worker).
//
// PARA QUÉ SIRVE (el problema real)
// El canal "Qobuz firmado" de la app necesita dos cosas: las claves
// (app_id/app_secret) y la API de Qobuz. Si la app las pide directo, cada
// USUARIO pega contra Qobuz (y contra el sitio que publique las claves): se ve
// el tráfico, se ve la huella de la app y un bloqueo deja a todos sin FLAC.
//
// Con este Worker, la app apunta a TU dominio (`qobuz_api_base` y/o
// `qobuz_keys_url`) y:
//   - las claves viven ACÁ, no en el teléfono de cada usuario;
//   - los usuarios hablan con tu dominio, no con un tercero;
//   - si el secreto rota, se arregla en UN lugar (este Worker), sin actualizar
//     la app ni repartir claves nuevas.
//
// CONTRATO (lo que la app espera)
//   GET /keys           → {"appId":"...","appSecret":"..."}   (venc. 5 min)
//   GET /pool[/<secreto>] → el POOL de sesiones de Qobuz, en texto plano, una
//                         línea "user_auth_token=<token>" por cuenta
//                         (con QOBUZ_POOL_SECRET, exige el secreto en la ruta
//                          o en ?s=; sin él, /pool queda abierto)
//   GET /api.json/0.2/* → relay FIRMADO a Qobuz
//
// CLAVES EN VIVO (por qué /keys NO es una foto fija)
// Qobuz rota app_id/app_secret de vez en cuando. Si el Worker guardara una copia
// cargada a mano, el día que roten TODOS los usuarios quedan sin FLAC hasta que
// alguien se acuerde de recargar el secreto. Para que la rotación se cure sola,
// /keys y el relay piden las claves a una FUENTE VIVA (por defecto
// https://flacdownloader.com/api/qobuz/keys, el mismo origen público que ya usa
// la app) y sólo caen a QOBUZ_APP_ID/QOBUZ_APP_SECRET si esa fuente falla o
// devuelve algo inválido. La respuesta se cachea 5 min en memoria del isolate (y
// 5 min en el edge), así que la fuente se toca como mucho una vez cada tanto
// aunque haya miles de usuarios. Y si el relay firma con claves que Qobuz ya
// rechaza (400/401), se recargan en el acto y se reintenta UNA vez: ésa es la
// cura sola. `QOBUZ_LIVE_KEYS_URL` apunta a otra fuente; con
// `QOBUZ_LIVE_KEYS_URL=""` se vuelve a la foto fija de los secretos. (El nombre
// lleva LIVE a propósito: `QOBUZ_KEYS_URL` es, en el build de la app, la URL del
// propio Worker; no confundirlas.)
//
// POR QUÉ /pool: el ajuste `qobuzPoolUrls` de la app descarga esta URL y saca
// las credenciales con su extractor (pares clave=valor, ver
// sessionpool.ExtraerCredencialesQobuz). El formato "user_auth_token=..." es el
// que ese extractor reconoce, así que NO sirvas los tokens sueltos, uno por
// línea sin la clave: no se leerían. Con este endpoint, el pool de cuentas vive
// en TU Worker y la app lo refresca sola, sin que nadie pegue nada.
//
// La firma va acá porque el app_secret no debe salir del Worker: la app manda
// la ruta + los parámetros, el Worker agrega app_id/request_ts/request_sig.
//
// DESPLIEGUE
//   1) wrangler init / wrangler deploy  (o pegar esto en el panel de Workers)
//   2) Variables del Worker: QOBUZ_APP_ID, QOBUZ_APP_SECRET (secret, respaldo de
//      la fuente viva), QOBUZ_AUTH_TOKENS (para /pool, una o más sesiones
//      separadas por coma), QOBUZ_POOL_SECRET (recomendado: protege /pool) y
//      opcional QOBUZ_USER_TOKEN si tenés cuenta con suscripción (FLAC real).
//      Opcional QOBUZ_LIVE_KEYS_URL para cambiar la fuente viva de claves.
//   3) En la app: Ajustes → Credenciales → Rescate de audio →
//      Origen de claves Qobuz: https://qobuz-proxy.guttural-engineer.workers.dev/<secreto-relay>/keys
//      (y, si querés que también la API pase por acá, qobuz_api_base apuntando
//       a https://qobuz-proxy.guttural-engineer.workers.dev/<secreto-relay>/api.json/0.2 con la ayuda de este mismo
//       Worker, que ya reenvía esa ruta.)
// ─────────────────────────────────────────────────────────────

const QOBUZ = "https://www.qobuz.com/api.json/0.2";

// Fuente VIVA de claves (no es un secreto: es el origen público que ya conoce
// cualquiera que haya mirado la app). Si querés otra, QOBUZ_LIVE_KEYS_URL.
const CLAVES_VIVAS_URL_POR_DEFECTO =
  "https://flacdownloader.com/api/qobuz/keys";
// Cuánto vale una lectura buena y cuánto una fallida. La buena es larga (no
// martillar a un tercero); la mala, corta, para reintentar pronto sin pagar la
// espera en cada petición.
const TTL_CLAVES_VIVAS_MS = 5 * 60 * 1000;
const TTL_CLAVES_FALLO_MS = 30 * 1000;

let cacheClavesVivas = { claves: null, vence: 0 };

// Sólo para los tests offline (verificar.mjs): deja el cache como recién nacido.
export function reiniciarCacheClavesVivas() {
  cacheClavesVivas = { claves: null, vence: 0 };
}

// clavesQobuz: devuelve {appId, appSecret} EN VIVO si se puede, o el respaldo de
// los secretos del Worker si la fuente falla. `forzar` saltea el cache (lo usa el
// relay cuando Qobuz contesta 400/401: casi siempre significa que rotaron).
// Nunca lanza: como mucho devuelve un par vacío y quien llama decide el 500.
async function clavesQobuz(env, forzar = false) {
  const ahora = Date.now();
  if (!forzar && cacheClavesVivas.claves && cacheClavesVivas.vence > ahora) {
    return cacheClavesVivas.claves;
  }
  const deRespaldo = {
    appId: String(env.QOBUZ_APP_ID || "").trim(),
    appSecret: String(env.QOBUZ_APP_SECRET || "").trim(),
  };
  const url = String(
    env.QOBUZ_LIVE_KEYS_URL === undefined || env.QOBUZ_LIVE_KEYS_URL === null
      ? CLAVES_VIVAS_URL_POR_DEFECTO
      : env.QOBUZ_LIVE_KEYS_URL,
  ).trim();
  if (url) {
    try {
      const respuesta = await fetch(url, {
        headers: { Accept: "application/json" },
        // Que el edge también guarde la lectura: ni nosotros repetimos la salida.
        cf: { cacheTtl: 300 },
      });
      if (respuesta.ok) {
        const datos = await respuesta.json();
        const appId = String(datos.appId || datos.app_id || "").trim();
        const appSecret = String(
          datos.appSecret || datos.app_secret || "",
        ).trim();
        if (appId && appSecret) {
          cacheClavesVivas = {
            claves: { appId, appSecret },
            vence: ahora + TTL_CLAVES_VIVAS_MS,
          };
          return cacheClavesVivas.claves;
        }
      }
    } catch (_) {
      // Fuente caída o lenta: se usa el respaldo y se reintenta pronto.
    }
  }
  cacheClavesVivas = { claves: deRespaldo, vence: ahora + TTL_CLAVES_FALLO_MS };
  return deRespaldo;
}

// md5 en hex (WebCrypto no expone MD5: se implementa acá, son 30 líneas y evita
// depender de un hash que no existe en la plataforma).
export function md5Hex(texto) {
  const s = [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5,
    9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11,
    16, 23, 4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10,
    15, 21,
  ];
  const K = [];
  for (let i = 0; i < 64; i++)
    K[i] = Math.floor(Math.abs(Math.sin(i + 1)) * 4294967296);
  const bytes = new TextEncoder().encode(texto);
  const largoBits = bytes.length * 8;
  const conRelleno = new Uint8Array((((bytes.length + 8) >> 6) + 1) * 64);
  conRelleno.set(bytes);
  conRelleno[bytes.length] = 0x80;
  new DataView(conRelleno.buffer).setUint32(
    conRelleno.length - 8,
    largoBits >>> 0,
    true,
  );
  new DataView(conRelleno.buffer).setUint32(
    conRelleno.length - 4,
    Math.floor(largoBits / 4294967296),
    true,
  );
  let a0 = 0x67452301,
    b0 = 0xefcdab89,
    c0 = 0x98badcfe,
    d0 = 0x10325476;
  const rot = (x, n) => (x << n) | (x >>> (32 - n));
  for (let off = 0; off < conRelleno.length; off += 64) {
    const M = new DataView(conRelleno.buffer, off, 64);
    const w = [];
    for (let i = 0; i < 16; i++) w[i] = M.getUint32(i * 4, true);
    let a = a0,
      b = b0,
      c = c0,
      d = d0;
    for (let i = 0; i < 64; i++) {
      let f, g;
      if (i < 16) {
        f = (b & c) | (~b & d);
        g = i;
      } else if (i < 32) {
        f = (d & b) | (~d & c);
        g = (5 * i + 1) % 16;
      } else if (i < 48) {
        f = b ^ c ^ d;
        g = (3 * i + 5) % 16;
      } else {
        f = c ^ (b | ~d);
        g = (7 * i) % 16;
      }
      f = (f + a + K[i] + w[g]) | 0;
      a = d;
      d = c;
      c = b;
      b = (b + rot(f, s[i])) | 0;
    }
    a0 = (a0 + a) | 0;
    b0 = (b0 + b) | 0;
    c0 = (c0 + c) | 0;
    d0 = (d0 + d) | 0;
  }
  const hex = (n) => {
    let out = "";
    for (let i = 0; i < 4; i++)
      out += ((n >>> (i * 8)) & 255).toString(16).padStart(2, "0");
    return out;
  };
  return hex(a0) + hex(b0) + hex(c0) + hex(d0);
}

// firmaQobuz: MD5( metodoSinBarras + pares "clavevalor" ORDENADOS + ts + secreto )
export function firmaQobuz(metodo, params, ts, secreto) {
  const texto = Object.keys(params)
    .sort()
    .map((k) => k + params[k])
    .join("");
  return md5Hex(metodo.replace(/\//g, "") + texto + ts + secreto);
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium: registro de códigos y reportes.
//
// Por qué vive acá y no en la app: la app llevaba COMPILADO un PAT de GitHub
// para leer y escribir `codes.json` del repo privado QuopTron/bitly_codes_premium
// (y para crear los issues del reporte). Ese token salía del APK con unzip +
// grep, y era un token CLÁSICO (acceso a todos los repos de la cuenta). Acá la
// llave vive en el entorno del Worker (`GITHUB_TOKEN`, secreto de Cloudflare) y
// la app solo manda el código.
//
// Rutas (el secreto va en la RUTA, como en /pool: la app no manda cabeceras):
//   POST /premium/<PREMIUM_SECRET>/verificar  {code}          → {estado}
//   POST /premium/<PREMIUM_SECRET>/usar       {code, firmado} → {ok}
//   POST /premium/<PREMIUM_SECRET>/reporte    {titulo,cuerpo} → {ok}
//
// Estados: activo | usado | cancelado | libre | no_encontrado.
// Si el registro no responde, la app NO bloquea la activación (la firma del
// código se verifica local): el "usado" queda pendiente y se reintenta después.
// ─────────────────────────────────────────────────────────────────────────────

const CODES_API =
  "https://api.github.com/repos/QuopTron/bitly_codes_premium/contents/codes.json";

// Clave PÚBLICA de los códigos firmados (Ed25519). Es pública a propósito:
// verifica y NO permite firmar (la privada vive en la máquina del dueño, ver
// scripts/keys/ y go_backend/internal/premium/firmados.go).
const CLAVE_PUBLICA_FIRMADOS = "DPVABxXjluqWrBCKM9d7dh4dpPYDYq6h22s2m+9gJ6g=";

function respuestaJson(datos, estado = 200) {
  return new Response(JSON.stringify(datos), {
    status: estado,
    headers: { "content-type": "application/json" },
  });
}

function b64urlABytes(texto) {
  const normal = String(texto).replace(/-/g, "+").replace(/_/g, "/");
  const crudo = atob(normal + "=".repeat((4 - (normal.length % 4)) % 4));
  const bytes = new Uint8Array(crudo.length);
  for (let i = 0; i < crudo.length; i++) bytes[i] = crudo.charCodeAt(i);
  return bytes;
}

// b64Utf8/deB64Utf8: codes.json lleva acentos (la clave "_NOTA"), y btoa() a
// secas explota con cualquier carácter fuera de latin1.
function b64Utf8(texto) {
  let binario = "";
  for (const b of new TextEncoder().encode(texto))
    binario += String.fromCharCode(b);
  return btoa(binario);
}

function deB64Utf8(b64) {
  const binario = atob(String(b64).replace(/\n/g, ""));
  const bytes = Uint8Array.from(binario, (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

// firmaFirmadaValida verifica un código BITLY2.… con la clave pública. Si la
// plataforma no soporta Ed25519 en WebCrypto devuelve false: nunca se anota un
// código sin verificar.
async function firmaFirmadaValida(codigo) {
  try {
    const partes = String(codigo).split(".");
    if (partes.length !== 3 || partes[0].toUpperCase() !== "BITLY2")
      return false;
    const clave = await crypto.subtle.importKey(
      "raw",
      b64urlABytes(CLAVE_PUBLICA_FIRMADOS),
      { name: "Ed25519" },
      false,
      ["verify"],
    );
    return await crypto.subtle.verify(
      { name: "Ed25519" },
      clave,
      b64urlABytes(partes[2]),
      b64urlABytes(partes[1]),
    );
  } catch {
    return false;
  }
}

const cabeceraGithub = (env) => ({
  Authorization: `token ${env.GITHUB_TOKEN}`,
  Accept: "application/vnd.github.v3+json",
  "User-Agent": "bitly-premium-worker",
});

// leerCodes devuelve {codes, sha} o null si el registro no se pudo leer.
async function leerCodes(env) {
  const resp = await fetch(CODES_API, { headers: cabeceraGithub(env) });
  if (!resp.ok) return null;
  let meta;
  try {
    meta = await resp.json();
  } catch {
    return null;
  }
  try {
    return { codes: JSON.parse(deB64Utf8(meta.content || "")), sha: meta.sha };
  } catch {
    return null;
  }
}

async function escribirCodes(env, codes, sha, mensaje) {
  const resp = await fetch(CODES_API, {
    method: "PUT",
    headers: { ...cabeceraGithub(env), "Content-Type": "application/json" },
    body: JSON.stringify({
      message: mensaje,
      content: b64Utf8(JSON.stringify(codes, null, 2)),
      sha,
    }),
  });
  return resp.ok;
}

async function manejarPremium(url, peticion, env) {
  const partes = url.pathname.split("/").filter(Boolean); // premium/<secreto>/<acción>
  const secreto = String(env.PREMIUM_SECRET || "").trim();
  if (!secreto || partes[1] !== secreto) {
    return respuestaJson({ error: "premium: secreto inválido" }, 403);
  }
  if (peticion.method !== "POST")
    return respuestaJson({ error: "método inválido" }, 405);
  if (!env.GITHUB_TOKEN)
    return respuestaJson({ error: "premium: falta GITHUB_TOKEN" }, 500);

  let cuerpo = {};
  try {
    cuerpo = await peticion.json();
  } catch {
    return respuestaJson({ error: "cuerpo inválido" }, 400);
  }
  const accion = partes[2] || "";
  const code = String(cuerpo.code || "").trim();
  if (accion !== "reporte" && !code)
    return respuestaJson({ error: "falta el código" }, 400);

  if (accion === "verificar") {
    const dados = await leerCodes(env);
    if (!dados) return respuestaJson({ error: "registro no disponible" }, 502);
    return respuestaJson({
      estado: dados.codes[code] ? dados.codes[code] : "no_encontrado",
    });
  }

  if (accion === "usar") {
    const dados = await leerCodes(env);
    if (!dados) return respuestaJson({ error: "registro no disponible" }, 502);
    if (!dados.codes[code]) {
      // Un código FIRMADO no necesita estar anotado: la firma prueba que salió
      // de la clave privada del dueño. Recién ahí se anota (queda en el
      // registro); un código legacy sin anotar se rechaza como siempre.
      const firmado = String(cuerpo.firmado || "") === "true";
      if (!firmado || !(await firmaFirmadaValida(code))) {
        return respuestaJson({ error: "no_encontrado" }, 404);
      }
    }
    dados.codes[code] = "usado";
    const ok = await escribirCodes(
      env,
      dados.codes,
      dados.sha,
      "premium: código usado",
    );
    return respuestaJson(
      ok ? { ok: true } : { error: "no se pudo guardar" },
      ok ? 200 : 502,
    );
  }

  if (accion === "reporte") {
    const resp = await fetch(
      "https://api.github.com/repos/QuopTron/bitly/issues",
      {
        method: "POST",
        headers: { ...cabeceraGithub(env), "Content-Type": "application/json" },
        body: JSON.stringify({
          title: String(cuerpo.titulo || "Reporte de Bitly").slice(0, 200),
          body: String(cuerpo.cuerpo || "").slice(0, 20000),
        }),
      },
    );
    return respuestaJson(
      resp.ok ? { ok: true } : { error: "no se pudo crear el issue" },
      resp.ok ? 200 : 502,
    );
  }

  return respuestaJson({ error: "acción desconocida" }, 404);
}

export default {
  async fetch(peticion, env, ctx) {
    const url = new URL(peticion.url);

    // Secreto OPCIONAL que protege /keys y el relay (/api.json/0.2/*), que si no
    // quedan ABIERTOS: cualquiera con la URL firma con tus claves y gasta tu
    // cuota. Va como PRIMER segmento de la ruta (`/<secreto>/keys`,
    // `/<secreto>/api.json/0.2/…`) y no por cabecera a propósito: la app arma la
    // URL con `base + ruta + ?…` y no manda cabeceras propias al firmar. Sin
    // QOBUZ_RELAY_SECRET configurado nada cambia (compatibilidad); el /pool
    // tiene su propio secreto aparte y NO queda detrás de éste.
    const secretoGeneral = String(env.QOBUZ_RELAY_SECRET || "").trim();
    let prefijoOk = false;
    if (secretoGeneral) {
      const partes = url.pathname.split("/").filter(Boolean);
      if (partes[0] === secretoGeneral) {
        prefijoOk = true;
        url.pathname = "/" + partes.slice(1).join("/");
      }
    }
    const protegido =
      url.pathname === "/keys" || url.pathname.startsWith("/api.json/0.2/");
    if (secretoGeneral && protegido && !prefijoOk) {
      return new Response(
        JSON.stringify({ error: "proxy: secreto inválido" }),
        {
          status: 403,
          headers: { "content-type": "application/json" },
        },
      );
    }

    // Rate limiting por IP: corta el abuso ANTES de que se coma la cuota diaria
    // (100.000 peticiones en el plan gratis, y al pasarlas el Worker deja de
    // responder). El binding lo declara wrangler.toml ([[ratelimits]]); si no
    // está —build viejo, o plan que no lo soporta— no se limita nada.
    if (env.LIMITADOR && protegido) {
      const ip = peticion.headers.get("CF-Connecting-IP") || "sin-ip";
      const ambito = url.pathname === "/keys" ? "keys" : "api";
      const { success } = await env.LIMITADOR.limit({ key: `${ip}:${ambito}` });
      if (!success) {
        return new Response(
          JSON.stringify({ error: "demasiadas peticiones" }),
          {
            status: 429,
            headers: { "content-type": "application/json" },
          },
        );
      }
    }

    // Registro de códigos premium y reportes: acá vive la llave de GitHub, no en
    // la app (ver manejarPremium). Se atiende antes que el resto de las rutas.
    if (url.pathname === "/premium" || url.pathname.startsWith("/premium/")) {
      return await manejarPremium(url, peticion, env);
    }

    if (url.pathname === "/keys") {
      // En vivo si se puede; respaldo de los secretos si no. Así, cuando Qobuz
      // rota las claves, la app las recibe nuevas sin que nadie toque el Worker.
      const claves = await clavesQobuz(env);
      if (!claves.appId || !claves.appSecret) {
        return new Response(
          JSON.stringify({
            error:
              "faltan QOBUZ_APP_ID/QOBUZ_APP_SECRET y la fuente viva no respondió",
          }),
          {
            status: 500,
            headers: { "content-type": "application/json" },
          },
        );
      }
      return new Response(
        JSON.stringify({ appId: claves.appId, appSecret: claves.appSecret }),
        {
          headers: {
            "content-type": "application/json",
            // La app también cachea 5 min; esto evita que un pico de usuarios
            // golpee el Worker sin necesidad. Y si rota la clave, en ≤5 min la
            // app ya está pidiendo la nueva.
            "cache-control": "public, max-age=300",
          },
        },
      );
    }

    // Pool de sesiones: /pool devuelve la lista de tokens en el formato que
    // la app sabe leer (una línea "user_auth_token=<token>" por cuenta).
    if (url.pathname === "/pool" || url.pathname.startsWith("/pool/")) {
      // Secreto OPCIONAL en la ruta: con QOBUZ_POOL_SECRET configurado, /pool
      // sólo responde si el secreto viaja en el camino (`/pool/<secreto>`) o en
      // la query (`?s=<secreto>`). Sin secreto configurado, /pool queda abierto
      // (compatibilidad), pero entonces la URL del pool es un secreto a la
      // vista: cualquiera con el link ve tus tokens.
      //
      // Va por RUTA y no por cabecera a propósito: el bajador de fuentes de la
      // app (sessionpool.DescargarFuente) no manda cabeceras propias, así que
      // una URL con el secreto es la única forma de autenticar sin cambiarla.
      const secreto = String(env.QOBUZ_POOL_SECRET || "").trim();
      if (secreto) {
        const porRuta = url.pathname.startsWith("/pool/")
          ? url.pathname.slice("/pool/".length)
          : "";
        const enviado = porRuta || String(url.searchParams.get("s") || "");
        if (enviado !== secreto) {
          return new Response(
            JSON.stringify({ error: "pool: secreto inválido" }),
            { status: 403, headers: { "content-type": "application/json" } },
          );
        }
      }

      const tokens = String(env.QOBUZ_AUTH_TOKENS || "")
        .split(",")
        .map((t) => t.trim())
        .filter((t) => t.length > 0);
      if (tokens.length === 0) {
        // La palabra "token" es a propósito: la app la lee y pone la fuente en
        // pausa con backoff en vez de pagar la espera en cada arranque.
        return new Response(
          JSON.stringify({
            error: "No healthy Qobuz tokens available (pool vacío)",
          }),
          { status: 503, headers: { "content-type": "application/json" } },
        );
      }
      return new Response(
        tokens.map((t) => `user_auth_token=${t}`).join("\n") + "\n",
        {
          headers: {
            "content-type": "text/plain; charset=utf-8",
            // Nada de caché: si rotás un token, la próxima bajada del pool ya
            // lo ve (docs no guarda esta respuesta).
            "cache-control": "no-store",
          },
        },
      );
    }

    // Relay firmado: /api.json/0.2/<ruta>?... → Qobuz con app_id/ts/sig.
    if (url.pathname.startsWith("/api.json/0.2/")) {
      const ruta = url.pathname.replace("/api.json/0.2", "");
      const params = {};
      for (const [k, v] of url.searchParams) {
        if (k !== "app_id" && k !== "request_ts" && k !== "request_sig")
          params[k] = v;
      }

      const cabeceras = {
        "User-Agent": "Mozilla/5.0",
        Accept: "application/json",
      };
      // El token de usuario va por CABECERA y NO se firma. Si el Worker lo
      // pisara con uno propio, cada usuario perdería SU sesión al apuntar la
      // app acá (y con ella el FLAC de su suscripción). Manda el del Worker si
      // está configurado; si no, se REENVÍA el que trajo quien llama (el de su
      // pool/ajustes), que es lo mismo que pasaría yendo directo a Qobuz.
      const tokenUsuario =
        env.QOBUZ_USER_TOKEN || peticion.headers.get("X-User-Auth-Token") || "";
      if (tokenUsuario) cabeceras["X-User-Auth-Token"] = tokenUsuario;

      // Cache del edge SÓLO para las llamadas idempotentes (búsquedas): la misma
      // consulta repetida por varios usuarios no vuelve a contar contra las
      // 100.000 peticiones diarias del plan gratis. `getFileUrl` queda afuera a
      // propósito: devuelve una URL de CDN con vida corta y cachearla serviría
      // enlaces muertos.
      const cache =
        typeof caches !== "undefined" && caches.default ? caches.default : null;
      const claveCache = new Request(url.toString(), { method: "GET" });
      const cacheable = cache && ruta === "/catalog/search";
      if (cacheable) {
        const guardada = await cache.match(claveCache);
        if (guardada) return guardada;
      }

      // Se firma con las claves EN VIVO. Y si Qobuz las rechaza (400/401 suele
      // significar que rotaron), se recargan y se reintenta UNA vez: el relay
      // también se cura solo. Las claves viejas en el cache no condenan a nadie.
      let respuesta;
      for (let intento = 0; intento < 2; intento++) {
        const claves = await clavesQobuz(env, intento > 0);
        if (!claves.appId || !claves.appSecret) {
          return new Response(JSON.stringify({ error: "proxy sin claves" }), {
            status: 500,
          });
        }
        const ts = String(Math.floor(Date.now() / 1000));
        const q = new URLSearchParams(params);
        q.set("app_id", claves.appId);
        q.set("request_ts", ts);
        q.set("request_sig", firmaQobuz(ruta, params, ts, claves.appSecret));
        respuesta = await fetch(`${QOBUZ}${ruta}?${q}`, {
          headers: cabeceras,
        });
        if (respuesta.status !== 400 && respuesta.status !== 401) break;
      }
      const cuerpo = await respuesta.text();
      const salida = new Response(cuerpo, {
        status: respuesta.status,
        headers: {
          "content-type":
            respuesta.headers.get("content-type") || "application/json",
          // Sin caché, la URL de CDN con vida corta nunca se guarda; cacheada,
          // 60 s cubren el pico de consultas repetidas sin servir catálogos
          // viejos.
          "cache-control": cacheable ? "public, max-age=60" : "no-store",
        },
      });
      if (cacheable && respuesta.status === 200) {
        const paraCache = salida.clone();
        if (ctx && typeof ctx.waitUntil === "function") {
          ctx.waitUntil(cache.put(claveCache, paraCache));
        } else {
          await cache.put(claveCache, paraCache);
        }
      }
      return salida;
    }

    return new Response("bitly qobuz proxy ok", { status: 200 });
  },
};
