// harness_js_test.go — arnés mínimo para ejecutar la lógica de una extensión con
// Node, SIN red.
//
// Por qué hace falta: la lógica de las extensiones vive en JS y desde Go no se
// puede llamar a una función interna de un index.js (el runtime del host no deja
// sustituir `http.get`). Node sí puede: el archivo es un SCRIPT, no un módulo, así
// que sus `function` de nivel superior quedan como globales del contexto; los
// globales del host (log, storage, settings, utils, http) se inyectan como stubs
// que tiran error si alguien intenta salir a la red. Con eso los parsers nuevos
// (tabla TOTP del web player, bloque ytcfg de YouTube) se prueban de verdad, con
// fixtures primero y con la página REAL en los tests marcados como de red.
//
// Si `node` no está en PATH el test se SALTEA, no falla: el repo no exige Node
// para compilar ni para el resto de los tests.
//
// Se conecta con: spotify-web/index.js (parsearSecretosTOTP, bundleWebPlayerDesdePagina),
// ytmusic-spotiflac/index.js (extraerYtcfg, extractYouTubeVisitorData/PlayerURL)
// y apple-music/index.js (verificarJWTApple, primerTokenValidoApple, tokensJWTApple).
package bundled_extensions

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

// stubsHostJS inyecta los globales que el host le da a la extensión. `http` y
// `fetch` tiran error a propósito: cualquier prueba que sin querer salga a la red
// falla fuerte en vez de depender del humor de un CDN.
const stubsHostJS = `
globalThis.registerExtension = function () {};
globalThis.log = { info() {}, warn() {}, error() {}, debug() {} };
globalThis.storage = { get() { return null; }, set() { return true; }, remove() {} };
globalThis.settings = {};
globalThis.utils = {
  randomUserAgent() { return "arnes"; },
  appUserAgent() { return "arnes"; },
  randomUUID() { return "00000000-0000-4000-8000-000000000000"; },
  hmacSHA1() { return []; },
};
globalThis.http = {
  get() { throw new Error("sin red en el arnes"); },
  post() { throw new Error("sin red en el arnes"); },
};
globalThis.fetch = function () { throw new Error("sin red en el arnes"); };
globalThis.__leer = function (ruta) { return require("fs").readFileSync(ruta, "utf8"); };
globalThis.__escribirTmp = function (nombre, texto) {
  const fs = require("fs");
  const os = require("os");
  const path = require("path");
  const destino = path.join(os.tmpdir(), nombre);
  fs.writeFileSync(destino, texto);
  return destino;
};
`

// ejecutarLogicaExtension corre [guion] en el contexto de la extensión [id] y
// devuelve lo que el guion imprimió. El guion puede llamar directamente a
// cualquier `function` de nivel superior del index.js y usar `__leer(ruta)` para
// leer fixtures que el test haya dejado en t.TempDir().
func ejecutarLogicaExtension(t *testing.T, id string, guion string) string {
	t.Helper()
	return ejecutarLogicaExtensionEnv(t, id, guion, nil)
}

// ejecutarLogicaExtensionEnv es igual pero con variables de entorno: es la vía
// para pasarle rutas de fixture al guion sin escaparlas (en Windows las rutas
// traen backslash y armarlas dentro del JS sería un nido de escapes).
func ejecutarLogicaExtensionEnv(t *testing.T, id string, guion string, env map[string]string) string {
	t.Helper()

	node, err := exec.LookPath("node")
	if err != nil {
		t.Skip("node no está en PATH: se saltea la prueba funcional del JS")
	}

	crudo, err := os.ReadFile(filepath.Join(".", id, "index.js"))
	if err != nil {
		t.Fatalf("%s: no se pudo leer index.js: %v", id, err)
	}

	programa := stubsHostJS + "\n" + string(crudo) + "\n" + guion + "\n"

	ruta := filepath.Join(t.TempDir(), "caso_"+id+".js")
	if err := os.WriteFile(ruta, []byte(programa), 0o600); err != nil {
		t.Fatalf("no se pudo escribir el arnés: %v", err)
	}

	cmd := exec.Command(node, ruta)
	if len(env) > 0 {
		cmd.Env = append(os.Environ(), mapaAEnv(env)...)
	}
	salida, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("node falló (%v):\n%s", err, salida)
	}
	return string(salida)
}

// mapaAEnv convierte el mapa a la forma "CLAVE=valor" que espera exec.
func mapaAEnv(env map[string]string) []string {
	out := make([]string, 0, len(env))
	for k, v := range env {
		out = append(out, k+"="+v)
	}
	return out
}
