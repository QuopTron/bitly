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
//   GET /api.json/0.2/* → relay FIRMADO a Qobuz
//
// La firma va acá porque el app_secret no debe salir del Worker: la app manda
// la ruta + los parámetros, el Worker agrega app_id/request_ts/request_sig.
//
// DESPLIEGUE
//   1) wrangler init / wrangler deploy  (o pegar esto en el panel de Workers)
//   2) Variables del Worker: QOBUZ_APP_ID, QOBUZ_APP_SECRET (secret),
//      y opcional QOBUZ_USER_TOKEN si tenés cuenta con suscripción (FLAC real).
//   3) En la app: Ajustes → Credenciales → Rescate de audio →
//      Origen de claves Qobuz: https://TU-WORKER.workers.dev/keys
//      (y, si querés que también la API pase por acá, qobuz_api_base apuntando
//       a https://TU-WORKER.workers.dev/api.json/0.2 con la ayuda de este mismo
//       Worker, que ya reenvía esa ruta.)
// ─────────────────────────────────────────────────────────────

const QOBUZ = "https://www.qobuz.com/api.json/0.2";

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

export default {
  async fetch(peticion, env) {
    const url = new URL(peticion.url);

    if (url.pathname === "/keys") {
      if (!env.QOBUZ_APP_ID || !env.QOBUZ_APP_SECRET) {
        return new Response(
          JSON.stringify({ error: "faltan QOBUZ_APP_ID/QOBUZ_APP_SECRET" }),
          {
            status: 500,
            headers: { "content-type": "application/json" },
          },
        );
      }
      return new Response(
        JSON.stringify({
          appId: env.QOBUZ_APP_ID,
          appSecret: env.QOBUZ_APP_SECRET,
        }),
        {
          headers: {
            "content-type": "application/json",
            // La app también cachea 5 min; esto evita que un pico de usuarios
            // golpee el Worker sin necesidad.
            "cache-control": "public, max-age=300",
          },
        },
      );
    }

    // Relay firmado: /api.json/0.2/<ruta>?... → Qobuz con app_id/ts/sig.
    if (url.pathname.startsWith("/api.json/0.2/")) {
      if (!env.QOBUZ_APP_ID || !env.QOBUZ_APP_SECRET) {
        return new Response(JSON.stringify({ error: "proxy sin claves" }), {
          status: 500,
        });
      }
      const ruta = url.pathname.replace("/api.json/0.2", "");
      const params = {};
      for (const [k, v] of url.searchParams) {
        if (k !== "app_id" && k !== "request_ts" && k !== "request_sig")
          params[k] = v;
      }
      const ts = String(Math.floor(Date.now() / 1000));
      const q = new URLSearchParams(params);
      q.set("app_id", env.QOBUZ_APP_ID);
      q.set("request_ts", ts);
      q.set("request_sig", firmaQobuz(ruta, params, ts, env.QOBUZ_APP_SECRET));

      const cabeceras = {
        "User-Agent": "Mozilla/5.0",
        Accept: "application/json",
      };
      if (env.QOBUZ_USER_TOKEN)
        cabeceras["X-User-Auth-Token"] = env.QOBUZ_USER_TOKEN;

      const respuesta = await fetch(`${QOBUZ}${ruta}?${q}`, {
        headers: cabeceras,
      });
      const cuerpo = await respuesta.text();
      return new Response(cuerpo, {
        status: respuesta.status,
        headers: {
          "content-type":
            respuesta.headers.get("content-type") || "application/json",
          // El getFileUrl devuelve una URL de CDN con vida corta: nada de cachés.
          "cache-control": "no-store",
        },
      });
    }

    return new Response("bitly qobuz proxy ok", { status: 200 });
  },
};
