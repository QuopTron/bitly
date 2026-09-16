// verificar.mjs — prueba el Worker SIN desplegarlo.
//
// Por qué existe: el Worker firma peticiones a Qobuz con MD5 hecho a mano. Un
// error ahí no rompe nada visible — la API simplemente devuelve 401 y el canal
// queda mudo. Acá se comprueba contra un vector calculado FUERA del proyecto
// (con hashlib de Python) y contra el contrato que espera la app.
//
// Uso: node deeplinks/proxy-qobuz/verificar.mjs

import { md5Hex, firmaQobuz } from "./worker.js";

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
  const respuesta = await worker.fetch(new Request("https://proxy.test/keys"), {
    QOBUZ_APP_ID: "APP1",
    QOBUZ_APP_SECRET: "SECRETO1",
  });
  const cuerpo = await respuesta.json();
  check("/keys responde 200", respuesta.status === 200, String(respuesta.status));
  check("devuelve appId+appSecret (lo que la app espera)", cuerpo.appId === "APP1" && cuerpo.appSecret === "SECRETO1", JSON.stringify(cuerpo));
  check("se cachea 5 min (no se golpea el Worker por canción)", (respuesta.headers.get("cache-control") || "").includes("300"));

  const sinClaves = await worker.fetch(new Request("https://proxy.test/keys"), {});
  check("sin claves configuradas avisa con 500 en vez de mentir", sinClaves.status === 500, String(sinClaves.status));
}

console.log("\n== 4) el relay NO deja que el app_secret salga del Worker ==");
{
  const { default: worker } = await import("./worker.js");
  const original = globalThis.fetch;
  let visto = null;
  globalThis.fetch = async (url, opts) => {
    visto = { url: String(url), headers: opts && opts.headers };
    return new Response('{"url":"https://cdn.qobuz.example/x.flac"}', {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  };
  const respuesta = await worker.fetch(
    new Request("https://proxy.test/api.json/0.2/track/getFileUrl?format_id=6&intent=stream&track_id=312055179"),
    { QOBUZ_APP_ID: "APP1", QOBUZ_APP_SECRET: "SECRETO1", QOBUZ_USER_TOKEN: "TOKEN_USUARIO" },
  );
  globalThis.fetch = original;

  const cuerpo = await respuesta.json();
  check("reenvía a la API de Qobuz", !!(visto && visto.url.startsWith("https://www.qobuz.com/api.json/0.2/track/getFileUrl")), visto ? visto.url : "sin fetch");
  check(
    "agrega app_id + request_ts + request_sig",
    !!(visto && /app_id=APP1/.test(visto.url) && /request_sig=[0-9a-f]{32}/.test(visto.url)),
    visto ? visto.url : "",
  );
  check("el token de usuario va por CABECERA (no rompe la firma)", visto && visto.headers["X-User-Auth-Token"] === "TOKEN_USUARIO");
  check("devuelve el JSON de Qobuz tal cual", cuerpo.url === "https://cdn.qobuz.example/x.flac", JSON.stringify(cuerpo));
  check("no-store: la URL de la CDN no se cachea", (respuesta.headers.get("cache-control") || "").includes("no-store"));
}

console.log(fallos === 0 ? "\nTODO OK\n" : "\n" + fallos + " FALLA(S)\n");
process.exit(fallos === 0 ? 0 : 1);
