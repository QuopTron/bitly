// internetarchive_test.go — Pruebas del proveedor Internet Archive.
//
// Verifica el contrato que sostiene esta fuente "sin cuentas":
//   - la búsqueda devuelve PISTAS (no items) y una sola por tema,
//   - cuando un item publica FLAC y MP3 del mismo tema se sirve el FLAC,
//   - la calidad pedida puede cambiar entre los hermanos FLAC/MP3,
//   - la duración se normaliza a milisegundos (el servicio mezcla formatos),
//   - los subproductos del item (carátulas, espectrogramas) nunca son pistas,
//   - no publica ISRC, y eso se dice explícitamente.
//
// Se conecta con: client.go, busqueda.go, detalle.go y audio.go.
// Parte del flujo: fuente de audio lossless sin sesión.
package internetarchive

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
)

// servidorFalso monta un archive.org mínimo: búsqueda + metadata.
func servidorFalso(t *testing.T, docs []docItem, items map[string]Item) (*httptest.Server, *int32) {
	t.Helper()
	var itemesLeidos int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case strings.HasPrefix(r.URL.Path, "/advancedsearch.php"):
			resp := respuestaBusqueda{}
			resp.Response.NumFound = len(docs)
			resp.Response.Docs = docs
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(resp)
		case strings.HasPrefix(r.URL.Path, "/metadata/"):
			id := strings.TrimPrefix(r.URL.Path, "/metadata/")
			item, ok := items[id]
			if !ok {
				w.WriteHeader(http.StatusNotFound)
				_, _ = w.Write([]byte(`{"error":"item no existe"}`))
				return
			}
			atomic.AddInt32(&itemesLeidos, 1)
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(item)
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	t.Cleanup(srv.Close)
	return srv, &itemesLeidos
}

// itemConFlac arma un item con el mismo tema en FLAC y MP3, más basura.
func itemConFlac(identifier string, titulo, creador string) Item {
	var it Item
	it.Metadata.Identifier = textoFlexible(identifier)
	it.Metadata.Title = titulo
	it.Metadata.Creator = textoFlexible(creador)
	it.Metadata.Date = textoFlexible("1995-08-05")
	it.Files = []Archivo{
		{Name: identifier + "_01.flac", Format: "Flac", Title: "Da Funk", Track: "1", Length: "177.41"},
		{Name: identifier + "_01.mp3", Format: "VBR MP3", Track: "1", Length: "177.41"},
		{Name: identifier + "_02.flac", Format: "Flac", Title: "Rollin'", Track: "2", Length: "4:30"},
		{Name: identifier + "_02.mp3", Format: "VBR MP3", Track: "2", Length: "4:30"},
		{Name: "cover.jpg", Format: "JPEG"},
		{Name: identifier + "_spectrogram.png", Format: "Spectrogram"},
	}
	return it
}

// TestBusquedaDevuelvePistasYUnaPorTema comprueba la hidratación: un item con
// FLAC y MP3 del mismo tema no debe producir pistas duplicadas.
func TestBusquedaDevuelvePistasYUnaPorTema(t *testing.T) {
	item := itemConFlac("show-1995", "Soiree Prophecy", "Daft Punk")
	srv, _ := servidorFalso(t, []docItem{{Identifier: "show-1995", Title: "Soiree Prophecy", Creator: "Daft Punk"}},
		map[string]Item{"show-1995": item})

	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	pistas, err := c.SearchTracks("daft punk", 10)
	if err != nil {
		t.Fatalf("la búsqueda no debía fallar: %v", err)
	}
	if len(pistas) != 2 {
		t.Fatalf("esperaba 2 pistas (una por tema), obtuve %d: %+v", len(pistas), pistas)
	}
	for _, p := range pistas {
		if p.Provider != name {
			t.Errorf("provider = %q", p.Provider)
		}
		if !strings.HasSuffix(p.ID, ".flac") {
			t.Errorf("se debía preferir el FLAC, id = %q", p.ID)
		}
		if p.CoverURL == "" || p.AlbumID != "show-1995" {
			t.Errorf("portada/álbum mal armados: %+v", p)
		}
	}
	if pistas[0].Duration != 177410 {
		t.Errorf("duración = %d, esperaba 177410 ms", pistas[0].Duration)
	}
	if pistas[1].Duration != 270000 {
		t.Errorf("duración \"4:30\" = %d, esperaba 270000 ms", pistas[1].Duration)
	}
}

// TestItemsConFlacVanPrimero: si hay dos items, el que publica lossless debe
// aparecer antes aunque archive.org devuelva el otro primero.
func TestItemsConFlacVanPrimero(t *testing.T) {
	soloMP3 := Item{}
	soloMP3.Metadata.Identifier = "solo-mp3"
	soloMP3.Metadata.Title = "Solo MP3"
	soloMP3.Files = []Archivo{{Name: "a.mp3", Format: "VBR MP3", Title: "Tema", Track: "1", Length: "100"}}

	srv, _ := servidorFalso(t,
		[]docItem{{Identifier: "solo-mp3", Title: "Solo MP3"}, {Identifier: "con-flac", Title: "Con Flac"}},
		map[string]Item{
			"solo-mp3": soloMP3,
			"con-flac": itemConFlac("con-flac", "Con Flac", "Banda"),
		})

	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	pistas, err := c.SearchTracks("cualquiera", 10)
	if err != nil {
		t.Fatalf("no debía fallar: %v", err)
	}
	if len(pistas) == 0 {
		t.Fatal("sin pistas")
	}
	if pistas[0].Provider != name || !strings.Contains(pistas[0].ID, "con-flac") {
		t.Errorf("el item con FLAC debía ir primero: %+v", pistas[0])
	}
}

// TestCalidadCambiaDeHermano: pedir MP3 de una pista FLAC (y al revés) debe
// devolver el archivo hermano, no fallar ni servir otra canción.
func TestCalidadCambiaDeHermano(t *testing.T) {
	item := itemConFlac("show-1995", "Soiree Prophecy", "Daft Punk")
	srv, _ := servidorFalso(t, nil, map[string]Item{"show-1995": item})

	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	urlFlac, err := c.GetStreamURL("ia:show-1995/show-1995_01.flac", "FLAC")
	if err != nil {
		t.Fatalf("FLAC: %v", err)
	}
	if !strings.HasSuffix(urlFlac, "show-1995_01.flac") {
		t.Errorf("url FLAC = %q", urlFlac)
	}

	urlMP3, err := c.GetStreamURL("ia:show-1995/show-1995_01.flac", "MP3_320")
	if err != nil {
		t.Fatalf("MP3: %v", err)
	}
	if !strings.HasSuffix(urlMP3, "show-1995_01.mp3") {
		t.Errorf("se debía degradar al hermano MP3, url = %q", urlMP3)
	}

	// Y sin hermano del formato pedido se sirve el que hay (no se falla).
	urlSinHermano, err := c.GetStreamURL("ia:show-1995/show-1995_02.flac", "MP3_128")
	if err != nil {
		t.Fatalf("sin hermano: %v", err)
	}
	if !strings.HasSuffix(urlSinHermano, "show-1995_02.mp3") {
		t.Errorf("url = %q", urlSinHermano)
	}
}

// TestGetTrackDetalle arma la ficha desde la metadata del item.
func TestGetTrackDetalle(t *testing.T) {
	item := itemConFlac("show-1995", "Soiree Prophecy", "Daft Punk")
	srv, _ := servidorFalso(t, nil, map[string]Item{"show-1995": item})

	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	pista, err := c.GetTrack("ia:show-1995/show-1995_01.flac")
	if err != nil {
		t.Fatalf("GetTrack: %v", err)
	}
	if pista.Title != "Da Funk" || pista.Artist != "Daft Punk" || pista.Album != "Soiree Prophecy" {
		t.Errorf("ficha mal armada: %+v", pista)
	}

	album, err := c.GetAlbum("show-1995")
	if err != nil {
		t.Fatalf("GetAlbum: %v", err)
	}
	if album.TrackCount != 4 { // 2 FLAC + 2 MP3, sin contar portada ni espectrograma
		t.Errorf("trackCount = %d, esperaba 4", album.TrackCount)
	}
	if album.ReleaseDate != "1995-08-05" {
		t.Errorf("fecha = %q", album.ReleaseDate)
	}
}

// TestMetadataSeCachea: una segunda lectura del mismo item no debe volver a
// pedirlo por red (las búsquedas se repiten al teclear).
func TestMetadataSeCachea(t *testing.T) {
	item := itemConFlac("show-1995", "Soiree Prophecy", "Daft Punk")
	srv, leidos := servidorFalso(t, nil, map[string]Item{"show-1995": item})

	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	if _, err := c.GetTrack("ia:show-1995/show-1995_01.flac"); err != nil {
		t.Fatalf("primera: %v", err)
	}
	if _, err := c.GetTrack("ia:show-1995/show-1995_02.flac"); err != nil {
		t.Fatalf("segunda: %v", err)
	}
	if n := *leidos; n != 1 {
		t.Errorf("esperaba 1 lectura de metadata, hubo %d", n)
	}
}

// TestDuracionMSParseaAmbosFormatos: el servicio mezcla segundos y mm:ss.
func TestDuracionMSParseaAmbosFormatos(t *testing.T) {
	casos := map[string]int{
		"177.41":  177410,
		"34:38":   2078000,
		"1:02:03": 3723000,
		"":        0,
		"basura":  0,
	}
	for entrada, esperado := range casos {
		if got := duracionMS(entrada); got != esperado {
			t.Errorf("duracionMS(%q) = %d, esperaba %d", entrada, got, esperado)
		}
	}
}

// TestClasificarArchivo separa audio real de los subproductos del item.
func TestClasificarArchivo(t *testing.T) {
	casos := map[string]TipoAudio{
		"Flac":               Lossless,
		"24bit Flac":         Lossless,
		"WAVE":               Lossless,
		"VBR MP3":            Lossy,
		"Ogg Vorbis":         Lossy,
		"Item Tile":          NoAudio,
		"JPEG":               NoAudio,
		"Spectrogram":        NoAudio,
		"Metadata":           NoAudio,
		"Archive BitTorrent": NoAudio,
	}
	for formato, esperado := range casos {
		if got := clasificarArchivo(formato); got != esperado {
			t.Errorf("clasificarArchivo(%q) = %v, esperaba %v", formato, got, esperado)
		}
	}
}

// TestPartirID valida el formato de id y rechaza basura.
func TestPartirID(t *testing.T) {
	id, archivo, err := partirID("ia:show-1995/disc1/track 01.flac")
	if err != nil {
		t.Fatalf("id válido rechazado: %v", err)
	}
	if id != "show-1995" || archivo != "disc1/track 01.flac" {
		t.Errorf("partición = %q / %q", id, archivo)
	}
	for _, malo := range []string{"", "ia:", "ia:soloitem", "ia:/archivo.flac"} {
		if _, _, err := partirID(malo); err == nil {
			t.Errorf("id inválido aceptado: %q", malo)
		}
	}
}

// TestSinResultadosNoEsError: una búsqueda vacía no debe reportar fallo.
func TestSinResultadosNoEsError(t *testing.T) {
	srv, _ := servidorFalso(t, nil, map[string]Item{})
	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	pistas, err := c.SearchTracks("zzzz no existe", 5)
	if err != nil {
		t.Fatalf("no debía fallar: %v", err)
	}
	if len(pistas) != 0 {
		t.Errorf("esperaba 0 pistas, obtuve %d", len(pistas))
	}
}

// TestNoPublicaISRC: sin ISRC no puede confirmar grabación exacta, y el error
// debe decirlo (es lo que hace que el rescate siga con otra fuente).
func TestNoPublicaISRC(t *testing.T) {
	c := NewClient(nil)
	if _, err := c.GetTrackByISRC("USWB12403528"); err == nil {
		t.Fatal("debía fallar: esta fuente no publica ISRC")
	}
	if _, err := c.GetStreamURL("basura", "FLAC"); err == nil {
		t.Fatal("un id inválido no debía resolver")
	}
}

// TestBuscarColeccionesUsaMediatypeCollection deja claro que las playlists son
// colecciones de archive.org, no items de audio.
func TestBuscarColeccionesUsaMediatypeCollection(t *testing.T) {
	var consulta string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		consulta = r.URL.Query().Get("q")
		resp := respuestaBusqueda{}
		resp.Response.Docs = []docItem{{Identifier: "etree", Title: "Live Music Archive"}}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer srv.Close()

	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	playlists, err := c.SearchPlaylists("rock", 5)
	if err != nil {
		t.Fatalf("playlists: %v", err)
	}
	if !strings.Contains(consulta, "mediatype:collection") {
		t.Errorf("consulta sin filtro de colección: %q", consulta)
	}
	if len(playlists) != 1 || playlists[0].ID != "etree" {
		t.Errorf("playlists = %+v", playlists)
	}
}

// TestNombreDelProveedor: el id debe coincidir con el registrado en el backend
// (si cambia, la fuente deja de aparecer en streaming y descarga).
func TestNombreDelProveedor(t *testing.T) {
	if got := NewClient(nil).Name(); got != "internetarchive" {
		t.Errorf("Name() = %q", got)
	}
}
