// spotify_totp_rescate_test.go — Guardas del rescate de la tabla TOTP de
// spotify-web.
//
// Qué se está cuidando: la extensión firma /api/token con TOTP, y el secreto
// estaba SOLO hardcodeado. Cuando Spotify rota la versión (59 → 60 → 61) el
// endpoint empieza a responder 400/401 y la fuente se cae entera hasta que
// alguien pegue la tabla nueva a mano. El rescate la lee del bundle del web
// player, y la URL de ese bundle la publica el bloque de arranque de la página
// (`<script id="__CDN_FILE_URLS__">`) — la ruta sin hash responde 404, así que el
// bloque no es decorativo: es la única forma de ubicar el archivo.
//
// Tres capas, y cada una por una razón distinta:
//
//  1. TestSpotifyConservaElRescateDelTOTP — guarda de TEXTO. Evita el borrado
//     silencioso de las piezas que costó medir (el bloque, el parser, el
//     reintento, la persistencia). Falla explicando qué se pierde.
//  2. TestSpotifyRescateTOTP… — prueba FUNCIONAL con fixtures: ejecuta el JS real
//     (vía node, sin red) y exige que el parser devuelva BYTE A BYTE la misma
//     tabla que la copia de fábrica. Es la prueba de que el rescate sirve.
//  3. TestSpotifyTOTPRescateRedReal (BITLY_SP_TOTP_RED=1) — contrato con el
//     mundo: que la página siga publicando el bloque y que el bundle siga
//     trayendo la tabla, comparada contra la de fábrica.
package bundled_extensions

import (
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestSpotifyConservaElRescateDelTOTP(t *testing.T) {
	codigo := leerExtension(t, "spotify-web")

	piezas := []struct {
		nombre string
		marca  string
		porQue string
	}{
		{
			nombre: "lectura del bloque de arranque",
			marca:  "__CDN_FILE_URLS__",
			porQue: "es donde la página publica la URL del bundle; la ruta SIN hash del CDN responde 404, así que sin el bloque no hay bundle que leer",
		},
		{
			nombre: "parser de la tabla",
			marca:  "parsearSecretosTOTP",
			porQue: "traduce el literal del bundle ({secret:'…',version:N}) al formato de TOTP_SECRETS; sin esto la tabla leída no se puede usar",
		},
		{
			nombre: "reintento del rescate en getAccessToken",
			marca:  "rescatarSecretosTOTP()",
			porQue: "el rescate solo tiene sentido si se dispara cuando el endpoint rechazó el código viejo",
		},
		{
			nombre: "adopción del conjunto completo",
			marca:  "TOTP_SECRETS[versiones[i]]",
			porQue: "adoptar solo la versión más nueva deja sin respaldo a las anteriores; el bundle trae todas",
		},
		{
			nombre: "tabla recordada entre arranques",
			marca:  "cargarTOTPRescatado",
			porQue: "sin persistencia, tras una rotación cada arranque de la app paga un fallo de token solo para volver a rescatar",
		},
	}
	for _, p := range piezas {
		if !strings.Contains(codigo, p.marca) {
			t.Errorf("falta %s (%s): %s", p.nombre, p.marca, p.porQue)
		}
	}

	// TOTP_VERSION tiene que poder moverse: si vuelve a ser const, el rescate
	// lee la tabla nueva pero seguiría firmando con la versión vieja.
	if strings.Contains(codigo, "const TOTP_VERSION") {
		t.Error("TOTP_VERSION volvió a ser const: el rescate no puede subir la versión")
	}
}

// fixtureBundleTOTP es un recorte REAL del bundle del web player (los tres
// secretos, con las dos formas de comilla y el backslash escapado que trae el de
// la 60). Se usa en crudo para que valide el mismo camino que el bundle de hoy.
const fixtureBundleTOTP = `var basura="version:1";let tabla=[` +
	`{secret:',7/*F("rLJ2oxaKL^f+E1xvP@N',version:61},` +
	`{secret:'OmE{ZA.J^":0FG\\Uz?[@WW',version:60},` +
	`{secret:"{iOFn;4}<1PFYKPV?5{%u14]M>/V0hDH",version:59}` +
	`].map(e=>{var t;return t});`

// tablaTOTPEsperada son los bytes que el parser tiene que devolver: los mismos
// que la copia de fábrica de la extensión (por eso el test compara contra
// TOTP_SECRETS en vez de contra un número escrito a mano).
var tablaTOTPEsperada = map[string][]int{
	"61": {44, 55, 47, 42, 70, 40, 34, 114, 76, 74, 50, 111, 120, 97, 75, 76, 94, 102, 43, 69, 49, 120, 118, 80, 64, 78},
	"60": {79, 109, 69, 123, 90, 65, 46, 74, 94, 34, 58, 48, 70, 71, 92, 85, 122, 63, 91, 64, 87, 87},
	"59": {123, 105, 79, 70, 110, 59, 52, 125, 60, 49, 80, 70, 89, 75, 80, 86, 63, 53, 123, 37, 117, 49, 52, 93, 77, 62, 47, 86, 48, 104, 68, 72},
}

// guionSpotifyTOTP deja que el JS real haga el trabajo y devuelve un JSON con lo
// que encontró, para que el test opine en Go.
const guionSpotifyTOTP = `
const pagina = __leer(process.env.BITLY_FIX_PAGINA);
const bundle = __leer(process.env.BITLY_FIX_BUNDLE);
const url = bundleWebPlayerDesdePagina(pagina);
const tabla = url ? parsearSecretosTOTP(bundle) : {};
const fabrica = TOTP_SECRETS;
const salida = { url: url, versiones: Object.keys(tabla).map(Number).sort((a, b) => a - b), igual: {}, fabrica: fabrica };
for (const v of Object.keys(fabrica)) {
  salida.igual[v] = JSON.stringify(tabla[v]) === JSON.stringify(fabrica[v]);
}
process.stdout.write(JSON.stringify(salida));
`

// TestSpotifyRescateTOTPLeeElBloqueDeArranque corre el JS de la extensión contra
// una página fixture cuyo bloque __CDN_FILE_URLS__ es el único lugar donde está
// la URL del bundle (la entrada sin hash está ahí para probar que se elige la
// hasheada) y contra el recorte real de tabla del bundle.
func TestSpotifyRescateTOTPLeeElBloqueDeArranque(t *testing.T) {
	const urlBundle = "https://open.spotifycdn.com/cdn/build/web-player/web-player.abc123dead.js"

	mapa := `{` +
		`"build/web-player/web-player.js":"https://open.spotifycdn.com/cdn/build/web-player/web-player.js",` +
		`"build/web-player/web-player.abc123dead.js":"` + urlBundle + `",` +
		`"build/web-player/encore~web-player.99.js":"https://open.spotifycdn.com/cdn/build/web-player/encore~web-player.99.js",` +
		`"build/mobile-web-player/mobile-web-player.5.js":"https://open.spotifycdn.com/cdn/build/mobile-web-player/mobile-web-player.5.js"` +
		`}`
	pagina := `<!doctype html><html><head>` +
		`<script id="appServerConfig" type="text/plain">e30=</script>` +
		`<script id="__CDN_FILE_URLS__" type="text/plain">` +
		base64.StdEncoding.EncodeToString([]byte(mapa)) +
		`</script></head><body></body></html>`

	dir := t.TempDir()
	rutaPagina := escribirFixture(t, dir, "pagina.html", pagina)
	rutaBundle := escribirFixture(t, dir, "bundle.js", fixtureBundleTOTP)

	salida := ejecutarLogicaExtensionEnv(t, "spotify-web", guionSpotifyTOTP, map[string]string{
		"BITLY_FIX_PAGINA": rutaPagina,
		"BITLY_FIX_BUNDLE": rutaBundle,
	})

	var got struct {
		URL       string           `json:"url"`
		Versiones []int            `json:"versiones"`
		Igual     map[string]bool  `json:"igual"`
		Fabrica   map[string][]int `json:"fabrica"`
	}
	if err := json.Unmarshal([]byte(salida), &got); err != nil {
		t.Fatalf("salida del arnés ilegible (%v): %s", err, salida)
	}

	if got.URL != urlBundle {
		t.Errorf("bundle elegido = %q, se esperaba el hasheado %q (la ruta sin hash responde 404)", got.URL, urlBundle)
	}

	// La tabla de fábrica y la esperada tienen que ser la misma: si alguien
	// actualiza TOTP_SECRETS sin actualizar este test (o al revés), esto lo dice.
	if len(got.Fabrica) != len(tablaTOTPEsperada) {
		t.Errorf("TOTP_SECRETS tiene %d versiones, el fixture espera %d", len(got.Fabrica), len(tablaTOTPEsperada))
	}
	for v, esperado := range tablaTOTPEsperada {
		fabrica, ok := got.Fabrica[v]
		if !ok {
			t.Errorf("TOTP_SECRETS ya no trae la versión %s (el fixture la usa)", v)
			continue
		}
		if !enterosIguales(fabrica, esperado) {
			t.Errorf("TOTP_SECRETS[%s] cambió: el fixture del bundle espera otros bytes", v)
		}
		if !got.Igual[v] {
			t.Errorf("el parser NO reprodujo TOTP_SECRETS[%s]: el rescate devolvería un secreto distinto", v)
		}
	}
	if len(got.Versiones) != 3 {
		t.Errorf("versiones parseadas = %v, se esperaban 59, 60 y 61", got.Versiones)
	}
}

// TestSpotifyRescateTOTPCaeAlSrcSiNoHayBloque cubre la variante de página que no
// trae el bloque: ahí la URL tiene que salir del `src=` del HTML y relativizarse.
func TestSpotifyRescateTOTPCaeAlSrcSiNoHayBloque(t *testing.T) {
	pagina := `<!doctype html><html><head>` +
		`<script defer src="/cdn/build/web-player/web-player.sinhash.js"></script>` +
		`</head><body></body></html>`

	dir := t.TempDir()
	rutaPagina := escribirFixture(t, dir, "pagina.html", pagina)
	rutaBundle := escribirFixture(t, dir, "bundle.js", fixtureBundleTOTP)

	salida := ejecutarLogicaExtensionEnv(t, "spotify-web", guionSpotifyTOTP, map[string]string{
		"BITLY_FIX_PAGINA": rutaPagina,
		"BITLY_FIX_BUNDLE": rutaBundle,
	})

	var got struct {
		URL string `json:"url"`
	}
	if err := json.Unmarshal([]byte(salida), &got); err != nil {
		t.Fatalf("salida del arnés ilegible (%v): %s", err, salida)
	}
	const esperado = "https://open.spotify.com/cdn/build/web-player/web-player.sinhash.js"
	if got.URL != esperado {
		t.Errorf("bundle elegido = %q, se esperaba %q", got.URL, esperado)
	}
}

// TestSpotifyTOTPRescateRedReal comprueba, contra la web real, que el rescate
// sigue teniendo de dónde leer: que open.spotify.com publique el bloque, que la
// URL del bundle responda y que su tabla siga coincidiendo byte a byte con la
// copia de fábrica. Si algún día Spotify rota la versión, este test sigue verde
// (la tabla del bundle es la fuente) pero deja de estarlo si el bloque o el
// bundle cambian de forma, que es justo lo que hay que enterarse.
//
//	BITLY_SP_TOTP_RED=1 go test ./internal/bundled_extensions -run TestSpotifyTOTPRescateRedReal -v
func TestSpotifyTOTPRescateRedReal(t *testing.T) {
	if os.Getenv("BITLY_SP_TOTP_RED") != "1" {
		t.Skip("test de red: se activa con BITLY_SP_TOTP_RED=1")
	}

	pagina := bajarConUA(t, "https://open.spotify.com")

	dir := t.TempDir()
	rutaPagina := escribirFixture(t, dir, "pagina.html", pagina)

	guionURL := `
const url = bundleWebPlayerDesdePagina(__leer(process.env.BITLY_FIX_PAGINA));
process.stdout.write(JSON.stringify({ url: url }));
`
	salida := ejecutarLogicaExtensionEnv(t, "spotify-web", guionURL, map[string]string{
		"BITLY_FIX_PAGINA": rutaPagina,
	})
	var infoURL struct {
		URL string `json:"url"`
	}
	if err := json.Unmarshal([]byte(salida), &infoURL); err != nil {
		t.Fatalf("salida del arnés ilegible (%v): %s", err, salida)
	}
	if infoURL.URL == "" {
		t.Fatal("la página real ya no publica la URL del bundle en el bloque de arranque")
	}

	bundle := bajarConUA(t, infoURL.URL)
	rutaBundle := escribirFixture(t, dir, "bundle.js", bundle)

	salida = ejecutarLogicaExtensionEnv(t, "spotify-web", guionSpotifyTOTP, map[string]string{
		"BITLY_FIX_PAGINA": rutaPagina,
		"BITLY_FIX_BUNDLE": rutaBundle,
	})
	var got struct {
		Versiones []int            `json:"versiones"`
		Igual     map[string]bool  `json:"igual"`
		Fabrica   map[string][]int `json:"fabrica"`
	}
	if err := json.Unmarshal([]byte(salida), &got); err != nil {
		t.Fatalf("salida del arnés ilegible (%v): %s", err, salida)
	}

	t.Logf("bundle real: %s", infoURL.URL)
	t.Logf("versiones en el bundle: %v · de fábrica: %d", got.Versiones, len(got.Fabrica))

	for v := range got.Fabrica {
		if !got.Igual[v] {
			t.Errorf("el bundle real no reproduce TOTP_SECRETS[%s]: el rescate devolvería otro secreto", v)
		}
	}
}

// escribirFixture deja el contenido en [dir]/[nombre] y devuelve la ruta.
func escribirFixture(t *testing.T, dir, nombre, contenido string) string {
	t.Helper()
	ruta := filepath.Join(dir, nombre)
	if err := os.WriteFile(ruta, []byte(contenido), 0o600); err != nil {
		t.Fatalf("no se pudo escribir el fixture %s: %v", nombre, err)
	}
	return ruta
}

// leerExtension devuelve el index.js embebido de [id].
func leerExtension(t *testing.T, id string) string {
	t.Helper()
	crudo, err := os.ReadFile(filepath.Join(".", id, "index.js"))
	if err != nil {
		t.Fatalf("%s: no se pudo leer index.js: %v", id, err)
	}
	return string(crudo)
}

// bajarConUA hace un GET con UA de navegador y devuelve el cuerpo (los dos sitios
// que se prueban acá responden 403 a un cliente sin UA).
func bajarConUA(t *testing.T, url string) string {
	t.Helper()
	cliente := &http.Client{Timeout: 45 * time.Second}
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatalf("petición inválida %s: %v", url, err)
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36")
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	res, err := cliente.Do(req)
	if err != nil {
		t.Fatalf("no se pudo bajar %s: %v", url, err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		t.Fatalf("%s respondió %s", url, res.Status)
	}
	cuerpo, err := io.ReadAll(res.Body)
	if err != nil {
		t.Fatalf("no se pudo leer la respuesta de %s: %v", url, err)
	}
	return string(cuerpo)
}

// enterosIguales compara dos listas de bytes/códigos.
func enterosIguales(a, b []int) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
