// runtime_url_test.go — Guard del polyfill de URL del sandbox.
//
// Por qué existe: las extensiones parsean los enlaces con new URL(url) y
// searchParams. El polyfill exponía get() pero NO has(), y las extensiones de
// YouTube (extractVideoId/extractPlaylistId/extractBrowseId) usan has() antes
// que nada: sin él, new URL tiraba TypeError y TODO enlace de YouTube se
// descartaba como "no video ID found" — el enlace no se podía ni buscar ni
// descargar.
//
// También fija que hostname no incluya el puerto, que es lo que las
// extensiones comparan contra "youtu.be" / "open.spotify.com" y que
// `protocol` siga el estándar ("https:", sin las barras), porque hay dos
// consumidores que lo comparan así y un valor no estándar los rompe en
// silencio:
//
//   - amazon: /^https?:$/.test(protocol) -> sin match, la extensión devuelve
//     null y NO resuelve ningún enlace de Amazon.
//   - ytmusic: protocol !== "http:" -> sin match, descarta el proveedor de PO
//     Token (0 candidatos) y YouTube queda siempre en itag=18.
//
// Estas dos formas (regex anclada y comparación exacta) se evalúan acá tal
// cual las usan las extensiones: si el polyfill vuelve a exponer "https://",
// el test falla antes de que el bug llegue al dispositivo.
//
// Se conecta con: runtime_global_helpers.go + runtime_url.go.
// Parte del flujo: resolución de enlaces compartidos (handleUrl) y PO Token.
package extensions

import "testing"

func TestPolyfillURLSearchParamsYHostname(t *testing.T) {
	rt := NewRuntime()
	cfg := DefaultConfig()
	cfg.TimeoutMs = 30000
	_, err := rt.RunJS(`
function check(cond, msg) { if (!cond) throw new Error(msg); }
function test() {
  // Enlace corto: sin query, hostname debe ser el host pelado.
  var corto = new URL("https://youtu.be/dQw4w9WgXcQ");
  check(corto.hostname === "youtu.be", "hostname youtu.be, fue " + corto.hostname);
  check(corto.searchParams.has("v") === false, "youtu.be no debe tener v");
  check(corto.pathname === "/dQw4w9WgXcQ", "pathname mal: " + corto.pathname);

  // Enlace largo: el id sale de searchParams.get("v").
  var largo = new URL("https://www.youtube.com/watch?v=abc123&list=PL1");
  check(largo.searchParams.has("v") === true, "watch debe tener v");
  check(largo.searchParams.get("v") === "abc123", "v mal: " + largo.searchParams.get("v"));
  check(largo.searchParams.get("list") === "PL1", "list mal");
  check(largo.searchParams.has("nope") === false, "has(nope) debe ser false");
  check(largo.searchParams.get("nope") === null, "get ausente debe ser null");

  // hostname sin puerto (las extensiones comparan el host pelado).
  var puerto = new URL("https://open.spotify.com:443/track/x");
  check(puerto.hostname === "open.spotify.com", "hostname con puerto: " + puerto.hostname);
  check(puerto.host === "open.spotify.com:443", "host debe llevar puerto: " + puerto.host);

  // protocol SEGÚN EL ESTÁNDAR: "https:" (los dos puntos, SIN barras).
  check(largo.protocol === "https:", "protocol https debe ser 'https:', fue " + largo.protocol);
  var plano = new URL("http://127.0.0.1:4416");
  check(plano.protocol === "http:", "protocol http debe ser 'http:', fue " + plano.protocol);
  check(plano.port === "4416", "puerto del proveedor local mal: " + plano.port);
  check(plano.href === "http://127.0.0.1:4416/", "href del proveedor local mal: " + plano.href);
  check(plano.origin === "http://127.0.0.1:4416", "origin con puerto mal: " + plano.origin);
  check(largo.origin === "https://www.youtube.com", "origin sin puerto mal: " + largo.origin);

  // Los DOS consumidores reales, tal cual los escriben las extensiones.
  // amazon: /^https?:$/.test(protocol)
  check(/^https?:$/.test(largo.protocol) === true, "amazon descartaría el enlace: protocol=" + largo.protocol);
  check(/^https?:$/.test(plano.protocol) === true, "amazon descartaría un enlace http: protocol=" + plano.protocol);
  // amazon: base = protocol + "//" + host  ->  https://host (y no https:////host)
  check(largo.protocol + "//" + largo.host === "https://www.youtube.com",
        "base de amazon mal armada: " + largo.protocol + "//" + largo.host);
  // ytmusic: normalizePoTokenProviderURL exige exactamente "http:"/"https:"
  check(plano.protocol !== "http:" && plano.protocol !== "https:" ? false : true,
        "ytmusic descartaría el proveedor de PO Token: protocol=" + plano.protocol);

  return "ok";
}
// Se LLAMA: RunJS solo evalúa el script, así que sin esta línea las
// aserciones nunca corren y el test pasaría con el polyfill roto.
test();
`, "url-test", "url-test", cfg, ".")
	if err != nil {
		t.Fatalf("polyfill de URL roto: %v", err)
	}
}
