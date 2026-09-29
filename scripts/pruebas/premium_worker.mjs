// premium_worker.mjs — Prueba de las rutas /premium/* del Worker.
//
// Por qué existe: esas rutas son las que ahora hacen el trabajo que antes hacía
// la app con un token compilado adentro (leer y escribir el registro de códigos
// y crear los issues de los reportes). Si se rompen, la validación local de un
// código sigue andando, pero nadie queda anotado como "usado" y los reportes no
// llegan: es un fallo silencioso, de los que conviene atrapar acá.
//
// No sale a internet: la API de GitHub se simula y la firma se hace con la clave
// privada real (scripts/keys/), así se comprueba el camino completo
// (firma Ed25519 → verificación WebCrypto en el Worker → anotado en el registro).
//
// Uso:  node scripts/pruebas/premium_worker.mjs
//
// Se conecta con: deeplinks/proxy-qobuz/worker.js, scripts/release/generar_codigo.py
import { execFileSync } from "node:child_process";

const SECRETO = "secreto-de-prueba";
const CODES = { _NOTA: "no tocar (acentos: código)", "legacy-1": "activo", "usado-1": "usado" };
let guardado = null;
let subidas = 0;

// ── GitHub simulado ─────────────────────────────────────────────────────────
globalThis.fetch = async (url, opciones = {}) => {
  const u = String(url);
  if (u.includes("bitly_codes_premium/contents/codes.json")) {
    if ((opciones.method || "GET") === "GET") {
      const contenido = Buffer.from(JSON.stringify(CODES, null, 2), "utf8").toString("base64");
      return new Response(JSON.stringify({ content: contenido, sha: "sha-viejo" }), { status: 200 });
    }
    guardado = JSON.parse(Buffer.from(JSON.parse(opciones.body).content, "base64").toString("utf8"));
    subidas++;
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }
  if (u.includes("api.github.com/repos/QuopTron/bitly/issues")) {
    return new Response(JSON.stringify({ ok: true }), { status: 201 });
  }
  throw new Error(`fetch inesperado: ${u}`);
};

const worker = (await import("../../deeplinks/proxy-qobuz/worker.js")).default;

const env = { PREMIUM_SECRET: SECRETO, GITHUB_TOKEN: "token-de-prueba" };
const pedir = (accion, cuerpo, e = env, secreto = SECRETO) =>
  worker.fetch(
    new Request(`https://worker.test/premium/${secreto}/${accion}`, {
      method: "POST",
      body: JSON.stringify(cuerpo),
      headers: { "content-type": "application/json" },
    }),
    e,
    {},
  );

const revisar = async (nombre, respuesta, esperado) => {
  const estado = respuesta.status;
  const datos = await respuesta.json();
  const ok = estado === esperado.status && (!esperado.estado || datos.estado === esperado.estado);
  console.log(`${ok ? "✔" : "✘"} ${nombre} → ${estado} ${JSON.stringify(datos)}`);
  if (!ok) process.exitCode = 1;
};

// ── 1) Consultar el registro ────────────────────────────────────────────────
await revisar("verificar un código activo", await pedir("verificar", { code: "legacy-1" }), {
  status: 200,
  estado: "activo",
});
await revisar("verificar un código usado", await pedir("verificar", { code: "usado-1" }), {
  status: 200,
  estado: "usado",
});
await revisar("verificar un código inexistente", await pedir("verificar", { code: "no-esta" }), {
  status: 200,
  estado: "no_encontrado",
});

// ── 2) Marcar como usado uno que ya está anotado ────────────────────────────
await revisar("marcar usado (ya anotado)", await pedir("usar", { code: "legacy-1" }), { status: 200 });
if (guardado?.["legacy-1"] !== "usado") {
  console.log("✘ el PUT no quedó con legacy-1 = usado");
  process.exitCode = 1;
}
if (guardado?._NOTA !== CODES._NOTA) {
  console.log("✘ el PUT perdió o rompió el _NOTA (acentos)");
  process.exitCode = 1;
}

// ── 3) Código FIRMADO que no está anotado: se verifica y se anota solo ──────
const firmado = execFileSync(
  "python",
  [
    new URL("../../scripts/release/generar_codigo.py", import.meta.url).pathname.replace(/^\//, ""),
    "--dias",
    "1",
    "--id",
    "prueba-worker",
  ],
  { encoding: "utf8" },
)
  .split("\n")[0]
  .trim();

const antes = subidas;
await revisar("anotar un código FIRMADO", await pedir("usar", { code: firmado, firmado: "true" }), {
  status: 200,
});
if (subidas === antes || guardado?.[firmado] !== "usado") {
  console.log("✘ el código firmado no se anotó como usado");
  process.exitCode = 1;
}

// Firmado = true pero con la firma manoseada → NO se anota.
const manoseado = firmado.slice(0, 40) + "X" + firmado.slice(41);
await revisar("código firmado MANOSEADO", await pedir("usar", { code: manoseado, firmado: "true" }), {
  status: 404,
});

// Legacy sin anotar y sin firma → como siempre: no se anota.
await revisar("legacy sin anotar y sin firma", await pedir("usar", { code: "inventado.abc" }), {
  status: 404,
});

// ── 4) Reporte ──────────────────────────────────────────────────────────────
await revisar("reporte", await pedir("reporte", { titulo: "[Bug] prueba", cuerpo: "detalle" }), {
  status: 200,
});

// ── 5) Protecciones ─────────────────────────────────────────────────────────
await revisar("secreto inválido", await pedir("verificar", { code: "legacy-1" }, env, "otro"), {
  status: 403,
});
await revisar(
  "sin GITHUB_TOKEN en el Worker",
  await pedir("verificar", { code: "legacy-1" }, { PREMIUM_SECRET: SECRETO }),
  { status: 500 },
);
await revisar("acción desconocida", await pedir("cualquiera", { code: "legacy-1" }), { status: 404 });

console.log(process.exitCode ? "HAY FALLAS" : "TODO OK");
