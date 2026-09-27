// apple_music_feed_test.go — Guardas del home feed de apple-music.
//
// Qué se está cuidando: el feed NO sale de la API con token. La página de Apple
// trae la lista ya renderizada para el navegador en el bloque
// `<script id="serialized-server-data">`, que es contenido PÚBLICO. De ahí se
// sacan las secciones (título en `header.item.titleLink.title`) y sus ítems
// (identidad en `contentDescriptor`: kind + storeAdamID). Si ese bloque cambia
// de forma, el feed se queda vacío SIN que falle nada, que es justo lo que este
// test tiene que notar.
//
// Dos capas:
//  1. TestAppleMusicConservaElFeedDelBloqueSsr — guarda de TEXTO.
//  2. TestAppleMusicFeedLeeElBloqueSsr — funcional con Node (sin red) contra un
//     fixture: exige que se deriven los títulos, se mapeen los tipos que la
//     extensión sabe abrir y se DESCARTEN radio/sin-título, y que el artwork se
//     concrete desde la plantilla {w}x{h}{c}.{f}.
package bundled_extensions

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestAppleMusicConservaElFeedDelBloqueSsr(t *testing.T) {
	codigo := leerExtension(t, "apple-music")

	piezas := []struct {
		nombre string
		marca  string
		porQue string
	}{
		{
			nombre: "lectura del bloque de arranque",
			marca:  "serialized-server-data",
			porQue: "es la única fuente del feed (público, sin token); sin el bloque no hay secciones",
		},
		{
			nombre: "título de sección",
			marca:  "header.item.titleLink.title",
			porQue: "las secciones de Apple no traen `title` propio; el nombre vive en el header",
		},
		{
			nombre: "identidad del ítem",
			marca:  "contentDescriptor",
			porQue: "de ahí salen el kind y el storeAdamID con el que el resto de la extensión abre el ítem",
		},
		{
			nombre: "concreción del artwork",
			marca:  "appleFeedArtwork",
			porQue: "la URL viene como plantilla {w}x{h}{c}.{f}; sin concretarla el cover no carga",
		},
		{
			nombre: "recorrido del bloque SSR",
			marca:  "appleSeccionesSsr",
			porQue: "es quien traduce el JSON de Apple al contrato del feed (title + items)",
		},
		{
			nombre: "registro del feed",
			marca:  "getHomeFeed: getHomeFeed",
			porQue: "sin registrar la función, el backend no la ve y el feed queda invisible",
		},
	}
	for _, p := range piezas {
		if !strings.Contains(codigo, p.marca) {
			t.Errorf("falta %s (%s): %s", p.nombre, p.marca, p.porQue)
		}
	}
}

// fixtureFeedApple es una página mínima con el bloque serialized-server-data:
// dos secciones válidas (canciones y álbum), una de radio y una sin header que
// deben descartarse, y la URL de artwork en su forma plantilla.
const fixtureFeedApple = `<!doctype html><html><head>` +
	`<script id="serialized-server-data" type="application/json">` +
	`{"data":[{"data":{"sections":[` +
	`{"header":{"item":{"titleLink":{"title":"Best New Songs"}}},` +
	`"items":[` +
	`{"title":"Patient Zero",` +
	`"artwork":{"dictionary":{"url":"https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/aa/bb/cc/art.jpg/{w}x{h}{c}.{f}"}},` +
	`"subtitleLinks":[{"title":"Taylor Swift"}],` +
	`"contentDescriptor":{"kind":"song","identifiers":{"storeAdamID":"6814997425"}}},` +
	`{"titleLinks":[{"title":"The Life of a Showgirl"}],` +
	`"artwork":{"dictionary":{"url":"https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/dd/ee/ff/art2.jpg/{w}x{h}{c}.{f}"}},` +
	`"subtitleLinks":[{"title":"Taylor Swift"}],` +
	`"contentDescriptor":{"kind":"album","identifiers":{"storeAdamID":"6814997249"}}}` +
	`]},` +
	`{"header":{"item":{"titleLink":{"title":"New This Week"}}},` +
	`"items":[` +
	`{"titleLinks":[{"title":"Club Mix 011"}],` +
	`"artwork":{"dictionary":{"url":"https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/11/22/33/art3.jpg/{w}x{h}{c}.{f}"}},` +
	`"subtitleLinks":[{"title":"Kaleena Zanders"}],` +
	`"contentDescriptor":{"kind":"album","identifiers":{"storeAdamID":"6812133186"}}}` +
	`]},` +
	`{"header":{"item":{"titleLink":{"title":"Listen to Live Radio Now"}}},` +
	`"items":[{"title":"Apple Music 1","contentDescriptor":{"kind":"radioStation","identifiers":{"storeAdamID":"ra.978194965"}}}]},` +
	`{"items":[{"titleLinks":[{"title":"sin header"}],"contentDescriptor":{"kind":"album","identifiers":{"storeAdamID":"1"}}}]}` +
	`]}}]}` +
	`</script></head><body></body></html>`

// guionAppleFeed extrae el bloque como lo hace getHomeFeed y devuelve las
// secciones ya traducidas, para que el test opine en Go.
const guionAppleFeed = `
const html = __leer(process.env.BITLY_FIX_PAGINA);
const bloque = html.match(/<script[^>]*id="serialized-server-data"[^>]*>([\s\S]*?)<\/script>/);
const secciones = bloque ? appleSeccionesSsr(JSON.parse(bloque[1])) : [];
process.stdout.write(JSON.stringify(secciones));
`

func TestAppleMusicFeedLeeElBloqueSsr(t *testing.T) {
	dir := t.TempDir()
	rutaPagina := escribirFixture(t, dir, "feed.html", fixtureFeedApple)

	salida := ejecutarLogicaExtensionEnv(t, "apple-music", guionAppleFeed, map[string]string{
		"BITLY_FIX_PAGINA": rutaPagina,
	})

	var secciones []struct {
		Title string `json:"title"`
		Items []struct {
			ID       string `json:"id"`
			Type     string `json:"type"`
			Name     string `json:"name"`
			Artists  string `json:"artists"`
			CoverURL string `json:"cover_url"`
		} `json:"items"`
	}
	if err := json.Unmarshal([]byte(salida), &secciones); err != nil {
		t.Fatalf("salida del arnés ilegible (%v): %s", err, salida)
	}

	if len(secciones) != 2 {
		t.Fatalf("secciones = %d, se esperaban 2 (la de radio y la sin título deben descartarse): %s", len(secciones), salida)
	}
	if secciones[0].Title != "Best New Songs" || secciones[1].Title != "New This Week" {
		t.Errorf("títulos = %q, %q; se esperaban Best New Songs / New This Week", secciones[0].Title, secciones[1].Title)
	}

	cancion := secciones[0].Items[0]
	if cancion.ID != "6814997425" || cancion.Type != "track" {
		t.Errorf("canción = id %q tipo %q, se esperaba 6814997425/track", cancion.ID, cancion.Type)
	}
	if cancion.Name != "Patient Zero" || cancion.Artists != "Taylor Swift" {
		t.Errorf("canción = %q de %q, se esperaba Patient Zero de Taylor Swift", cancion.Name, cancion.Artists)
	}
	if !strings.Contains(cancion.CoverURL, "600x600bb.jpg") {
		t.Errorf("cover de la canción = %q: no se concretó la plantilla {w}x{h}{c}.{f}", cancion.CoverURL)
	}

	album := secciones[0].Items[1]
	if album.Type != "album" || album.Name != "The Life of a Showgirl" {
		t.Errorf("álbum = tipo %q nombre %q; se esperaba album / The Life of a Showgirl (el nombre viene de titleLinks)", album.Type, album.Name)
	}
	if secciones[1].Items[0].ID != "6812133186" {
		t.Errorf("segundo álbum id = %q, se esperaba 6812133186", secciones[1].Items[0].ID)
	}
}
