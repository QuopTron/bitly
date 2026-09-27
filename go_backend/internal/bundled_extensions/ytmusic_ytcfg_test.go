// ytmusic_ytcfg_test.go — Guardas de la lectura del bloque de arranque de
// YouTube (`ytcfg.set({...})`) en ytmusic-spotiflac.
//
// Qué se está cuidando: el visitorData y la URL del player se sacaban con regex
// sobre TODO el watch page (1,3 MB de HTML con datos de la canción adentro). El
// bloque de arranque es la superficie con la que la propia página inicializa su
// player, y ahí los valores son únicos y no ambiguos: `"jsUrl"` aparece 12 veces
// en el watch page y PLAYER_JS_URL una sola, así que una página que traiga un
// valor viejo en los datos puede hacer que la regex arme el player equivocado.
//
// Mismo criterio que en SoundCloud (bloque de hidratación en vez de raspar todo
// el HTML) con una diferencia importante: acá el bloque NO es la única vía — si
// la página no lo trae, quedan los patrones de siempre. Las dos capas se prueban.
package bundled_extensions

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestYtmusicConservaLaLecturaDelBloqueYtcfg(t *testing.T) {
	codigo := leerExtension(t, "ytmusic-spotiflac")

	piezas := []struct {
		nombre string
		marca  string
		porQue string
	}{
		{
			nombre: "lector del bloque",
			marca:  "function extraerYtcfg(",
			porQue: "es el camino que lee VISITOR_DATA y PLAYER_JS_URL de la superficie estable de la página",
		},
		{
			nombre: "extractor de objeto balanceado",
			marca:  "function objetoJsonBalanceado(",
			porQue: "sin esto no se puede delimitar el objeto del bloque (las llaves de adentro cortarían el JSON)",
		},
		{
			nombre: "respaldo para bloques que no son JSON",
			marca:  "function clavesDeBloqueYtcfg(",
			porQue: "YouTube emite bloques con comillas simples (TIMING_INFO) que JSON.parse rechaza; sin el respaldo se pierde la config de ese bloque",
		},
		{
			nombre: "el bloque alimenta al visitorData",
			marca:  "extractYouTubeVisitorData(html, ytcfg)",
			porQue: "si no se le pasa el bloque, la función vuelve a la regex sobre todo el HTML",
		},
		{
			nombre: "el bloque alimenta a la URL del player",
			marca:  "extractYouTubePlayerURL(html, ytcfg)",
			porQue: "PLAYER_JS_URL del bloque es el valor exacto; la regex puede quedarse con un jsUrl viejo de los datos",
		},
		{
			nombre: "normalización de la URL del player",
			marca:  "function normalizarYouTubePlayerURL(",
			porQue: "el bloque entrega la ruta raíz (/s/player/…); el descifrado de firma necesita la URL absoluta",
		},
	}
	for _, p := range piezas {
		if !strings.Contains(codigo, p.marca) {
			t.Errorf("falta %s (%s): %s", p.nombre, p.marca, p.porQue)
		}
	}
}

// fixtureYtcfg es una página sintética con las tres formas que emite YouTube:
// un bloque JSON válido (el bueno), uno con comillas simples (no parseable) y la
// llamada de par clave/valor (sin objeto). Además trae un señuelo en los datos de
// la página con un PLAYER_JS_URL viejo: así el test demuestra que el bloque gana
// y que la regex, cuando se la usa sola, se queda con el viejo.
const fixtureYtcfg = `<!doctype html><html><head>` +
	`<script>var ytInitialPlayerResponse={"decoy":{"VISITOR_DATA":"visitante-viejo","jsUrl":"\/s\/player\/VIEJO\/player_ias.vflset\/en_US\/base.js"}};</script>` +
	`<script>ytcfg.set({"VISITOR_DATA":"visitante-del-bloque","PLAYER_JS_URL":"\/s\/player\/NUEVO\/player_es6.vflset\/en_US\/base.js","INNERTUBE_API_KEY":"AIzaSyCLAVE-DE-LA-PAGINA","INNERTUBE_CONTEXT_CLIENT_VERSION":"2.20260924.00.00"});</script>` +
	`<script>ytcfg.set({"CSI_SERVICE_NAME": 'youtube', "TIMING_INFO": {"GetPlayer_rid": '0xc50'}});</script>` +
	`<script>ytcfg.set("initialInnerWidth", window.innerWidth);</script>` +
	`</head><body></body></html>`

const guionYtmusicYtcfg = `
const html = __leer(process.env.BITLY_FIX_PAGINA);
const cfg = extraerYtcfg(html);
process.stdout.write(JSON.stringify({
  claves: Object.keys(cfg).length,
  visitorBloque: extractYouTubeVisitorData(html, cfg),
  playerBloque: extractYouTubePlayerURL(html, cfg),
  visitorRegex: extractYouTubeVisitorData(html, null),
  playerRegex: extractYouTubePlayerURL(html, null),
  apiKey: cfg.INNERTUBE_API_KEY || "",
  cliente: cfg.INNERTUBE_CONTEXT_CLIENT_VERSION || "",
  sinBloque: JSON.stringify(extraerYtcfg("pagina sin ytcfg")),
}));
`

// TestYtmusicPriorizaElBloqueSobreLaRegex corre el JS real contra la fixture y
// exige que el bloque gane, que el respaldo siga funcionando y que los bloques
// que no son JSON válido no rompan la lectura de los otros.
func TestYtmusicPriorizaElBloqueSobreLaRegex(t *testing.T) {
	dir := t.TempDir()
	rutaPagina := escribirFixture(t, dir, "watch.html", fixtureYtcfg)

	salida := ejecutarLogicaExtensionEnv(t, "ytmusic-spotiflac", guionYtmusicYtcfg, map[string]string{
		"BITLY_FIX_PAGINA": rutaPagina,
	})

	var got struct {
		Claves        int    `json:"claves"`
		VisitorBloque string `json:"visitorBloque"`
		PlayerBloque  string `json:"playerBloque"`
		VisitorRegex  string `json:"visitorRegex"`
		PlayerRegex   string `json:"playerRegex"`
		APIKey        string `json:"apiKey"`
		Cliente       string `json:"cliente"`
		SinBloque     string `json:"sinBloque"`
	}
	if err := json.Unmarshal([]byte(salida), &got); err != nil {
		t.Fatalf("salida del arnés ilegible (%v): %s", err, salida)
	}

	if got.VisitorBloque != "visitante-del-bloque" {
		t.Errorf("visitorData del bloque = %q, se esperaba el del bloque (no el señuelo de los datos)", got.VisitorBloque)
	}
	const playerBueno = "https://www.youtube.com/s/player/NUEVO/player_es6.vflset/en_US/base.js"
	if got.PlayerBloque != playerBueno {
		t.Errorf("player del bloque = %q, se esperaba %q", got.PlayerBloque, playerBueno)
	}
	if got.APIKey != "AIzaSyCLAVE-DE-LA-PAGINA" {
		t.Errorf("INNERTUBE_API_KEY del bloque = %q", got.APIKey)
	}
	if got.Cliente != "2.20260924.00.00" {
		t.Errorf("versión de cliente del bloque = %q", got.Cliente)
	}

	// El respaldo tiene que seguir vivo (páginas servidas sin el bloque) y, en
	// esta fixture, devolver el valor viejo a propósito: es la prueba de por qué
	// el bloque manda.
	if got.VisitorRegex != "visitante-viejo" {
		t.Errorf("respaldo por regex = %q, se esperaba el señuelo (el respaldo debe seguir funcionando)", got.VisitorRegex)
	}
	const playerViejo = "https://www.youtube.com/s/player/VIEJO/player_ias.vflset/en_US/base.js"
	if got.PlayerRegex != playerViejo {
		t.Errorf("respaldo por regex del player = %q, se esperaba %q", got.PlayerRegex, playerViejo)
	}

	// Una página sin bloque no debe romper nada: cfg vacío, cadena vacía.
	if got.SinBloque != "{}" {
		t.Errorf("extraerYtcfg sin bloque = %q, se esperaba {}", got.SinBloque)
	}
}
