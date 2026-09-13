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
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
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

// TestStreamURLUsaElNodoDirecto fija el ahorro medido contra archive.org:
// /download/<id>/<archivo> hace un 302 hacia el nodo real y ese salto cuesta
// ~1 s de TTFB, así que la URL debe salir apuntando al nodo cuando la metadata
// lo publica (d2/d1 + dir) y caer al canónico solo si no está.
func TestStreamURLUsaElNodoDirecto(t *testing.T) {
	conNodo := itemConFlac("show-1995", "Soiree Prophecy", "Daft Punk")
	conNodo.D1 = "ia800504.us.archive.org"
	conNodo.D2 = "dn720708.ca.archive.org"
	conNodo.Dir = "/26/items/show-1995"

	sinNodo := itemConFlac("sin-nodo", "Sin Nodo", "Banda")

	srv, _ := servidorFalso(t, nil, map[string]Item{"show-1995": conNodo, "sin-nodo": sinNodo})
	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	url, err := c.GetStreamURL("ia:show-1995/show-1995_01.flac", "FLAC")
	if err != nil {
		t.Fatalf("GetStreamURL: %v", err)
	}
	esperado := "https://dn720708.ca.archive.org/26/items/show-1995/show-1995_01.flac"
	if url != esperado {
		t.Errorf("url = %q, esperaba el nodo directo %q", url, esperado)
	}

	// El hermano MP3 del mismo item también sale por el nodo (mismo item, mismo
	// nodo): es el caso de una reproducción con otra calidad.
	urlMP3, err := c.GetStreamURL("ia:show-1995/show-1995_01.flac", "MP3_320")
	if err != nil {
		t.Fatalf("GetStreamURL MP3: %v", err)
	}
	if !strings.HasPrefix(urlMP3, "https://dn720708.ca.archive.org/26/items/show-1995/") {
		t.Errorf("el MP3 debía salir por el nodo: %q", urlMP3)
	}

	// Sin nodo en la metadata: URL canónica, que funciona igual (con el salto).
	urlSin, err := c.GetStreamURL("ia:sin-nodo/sin-nodo_01.flac", "FLAC")
	if err != nil {
		t.Fatalf("GetStreamURL sin nodo: %v", err)
	}
	if !strings.HasSuffix(urlSin, "/download/sin-nodo/sin-nodo_01.flac") {
		t.Errorf("debía caer al canónico, url = %q", urlSin)
	}
}

// TestBaseNodoDescartaLoInvalido: el host viene de un JSON ajeno, así que una
// respuesta rara (vacía, con barra o espacio) no debe producir una URL rota.
func TestBaseNodoDescartaLoInvalido(t *testing.T) {
	casos := []struct {
		nombre      string
		d2, d1, dir string
		espera      string
	}{
		{"prefiere d2", "dn72.ca.archive.org", "ia80.us.archive.org", "/0/items/x", "https://dn72.ca.archive.org/0/items/x"},
		{"cae a d1", "", "ia80.us.archive.org", "/0/items/x", "https://ia80.us.archive.org/0/items/x"},
		{"sin dir no hay nodo", "dn72.ca.archive.org", "", "", ""},
		{"host con barra descartado", "dn72/x", "", "/0/items/x", ""},
		{"dir sin barra inicial", "dn72.ca.archive.org", "", "0/items/x", "https://dn72.ca.archive.org/0/items/x"},
		{"nodo nil", "", "", "", ""},
	}
	for _, caso := range casos {
		it := &Item{D2: caso.d2, D1: caso.d1, Dir: caso.dir}
		if got := it.baseNodo(); got != caso.espera {
			t.Errorf("%s: baseNodo() = %q, esperaba %q", caso.nombre, got, caso.espera)
		}
	}
	var nulo *Item
	if got := nulo.baseNodo(); got != "" {
		t.Errorf("item nil = %q", got)
	}
}

// TestNombreDelProveedor: el id debe coincidir con el registrado en el backend
// (si cambia, la fuente deja de aparecer en streaming y descarga).
func TestNombreDelProveedor(t *testing.T) {
	if got := NewClient(nil).Name(); got != "internetarchive" {
		t.Errorf("Name() = %q", got)
	}
}

// TestBusquedaPrefiereTituloYReservaAlTextoLibre fija la estrategia de consulta
// medida contra el servicio: primero la frase en el título (el texto libre
// devolvía colecciones ajenas) y, solo si el título no trae NADA, el texto
// libre — que es el modo que sí sirve para consultas con artista incluido.
func TestBusquedaPrefiereTituloYReservaAlTextoLibre(t *testing.T) {
	var consultas []string
	tituloVacio := false
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		consultas = append(consultas, q)
		resp := respuestaBusqueda{}
		if strings.Contains(q, "title:") && !tituloVacio {
			resp.Response.Docs = []docItem{{Identifier: "kind-of-blue", Title: "Kind of Blue"}}
		} else if !strings.Contains(q, "title:") {
			resp.Response.Docs = []docItem{{Identifier: "otro", Title: "Otra cosa"}}
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer srv.Close()

	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	// 1) Con resultados por título: una sola consulta, y es la del título.
	if _, err := c.buscarItems("kind of blue", 5); err != nil {
		t.Fatalf("buscarItems: %v", err)
	}
	if len(consultas) != 1 {
		t.Fatalf("esperaba una sola consulta, hubo %d: %v", len(consultas), consultas)
	}
	if !strings.Contains(consultas[0], `title:"kind of blue"`) {
		t.Errorf("la primera consulta debía ser la frase en el título: %q", consultas[0])
	}

	// 2) Sin resultados por título: entra el texto libre como reserva.
	c2 := NewClient(nil)
	c2.SetBaseURL(srv.URL)
	consultas = nil
	tituloVacio = true
	if _, err := c2.buscarItems("so what miles davis", 5); err != nil {
		t.Fatalf("buscarItems (reserva): %v", err)
	}
	if len(consultas) != 2 {
		t.Fatalf("esperaba título + reserva, hubo %d: %v", len(consultas), consultas)
	}
	if strings.Contains(consultas[1], "title:") {
		t.Errorf("la reserva no debe volver a filtrar por título: %q", consultas[1])
	}
	if !strings.Contains(consultas[1], "so what miles davis") {
		t.Errorf("la reserva debía ser el texto libre: %q", consultas[1])
	}
}

// TestHidratacionEsSecuencialYSeCorta fija las dos decisiones de rendimiento
// verificadas contra archive.org: leer la metadata de los items UNO por uno
// (las ráfagas concurrentes la degradaban) y dejar de leer en cuanto hay
// suficientes pistas.
func TestHidratacionEsSecuencialYSeCorta(t *testing.T) {
	var (
		enCurso    int32
		maxEnCurso int32
		leidos     int32
	)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/advancedsearch.php") {
			resp := respuestaBusqueda{}
			resp.Response.Docs = []docItem{
				{Identifier: "item-1"}, {Identifier: "item-2"},
				{Identifier: "item-3"}, {Identifier: "item-4"},
			}
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(resp)
			return
		}
		id := strings.TrimPrefix(r.URL.Path, "/metadata/")
		actual := atomic.AddInt32(&enCurso, 1)
		for {
			max := atomic.LoadInt32(&maxEnCurso)
			if actual <= max || atomic.CompareAndSwapInt32(&maxEnCurso, max, actual) {
				break
			}
		}
		// Si la lectura fuera concurrente, el máximo subiría de 1.
		time.Sleep(15 * time.Millisecond)
		atomic.AddInt32(&leidos, 1)
		atomic.AddInt32(&enCurso, -1)

		var it Item
		it.Metadata.Identifier = textoFlexible(id)
		it.Metadata.Title = id
		it.Files = []Archivo{{Name: id + "_01.flac", Format: "Flac", Title: "Tema", Track: "1", Length: "100"}}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(it)
	}))
	defer srv.Close()

	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	// Cada item aporta 1 pista: con límite 2 solo deben leerse 2 items.
	pistas, err := c.SearchTracks("x", 2)
	if err != nil {
		t.Fatalf("SearchTracks: %v", err)
	}
	if len(pistas) != 2 {
		t.Fatalf("esperaba 2 pistas, obtuve %d", len(pistas))
	}
	if n := atomic.LoadInt32(&leidos); n != 2 {
		t.Errorf("debía leer 2 items (se corta al tener las pistas), leyó %d", n)
	}
	if m := atomic.LoadInt32(&maxEnCurso); m != 1 {
		t.Errorf("la lectura debía ser secuencial, hubo %d en paralelo", m)
	}
}

// TestHidratacionAcotadaALimiteDeItems: aunque la consulta traiga muchos items,
// no se leen más de los acotados (el tope también acota la latencia).
func TestHidratacionAcotadaALimiteDeItems(t *testing.T) {
	var leidos int32
	docs := make([]docItem, 0, 20)
	for i := 0; i < 20; i++ {
		docs = append(docs, docItem{Identifier: fmt.Sprintf("item-%02d", i)})
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/advancedsearch.php") {
			resp := respuestaBusqueda{}
			resp.Response.Docs = docs
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(resp)
			return
		}
		atomic.AddInt32(&leidos, 1)
		// Item sin audio: obliga a seguir leyendo el siguiente.
		var it Item
		it.Metadata.Identifier = textoFlexible(strings.TrimPrefix(r.URL.Path, "/metadata/"))
		it.Files = []Archivo{{Name: "cover.jpg", Format: "JPEG"}}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(it)
	}))
	defer srv.Close()

	c := NewClient(nil)
	c.SetBaseURL(srv.URL)
	// Ningún item aporta pistas, así que se lee hasta el tope de items…
	pistas, err := c.SearchTracks("x", 25)
	if err != nil {
		t.Fatalf("SearchTracks: %v", err)
	}
	if len(pistas) != 0 {
		t.Errorf("esperaba 0 pistas, obtuve %d", len(pistas))
	}
	// …y no más: los 20 items de la consulta nunca se leen enteros.
	if n := int(atomic.LoadInt32(&leidos)); n != maxItemsHidratados {
		t.Errorf("leyó %d items, esperaba exactamente %d", n, maxItemsHidratados)
	}
}

// TestTituloSospechosoPorPalabraCompleta fija la regla que evita mandar al
// final una canción legítima: la marca se busca como PALABRA, no como trozo de
// otra palabra ("discover" no es un "cover").
func TestTituloSospechosoPorPalabraCompleta(t *testing.T) {
	casos := []struct {
		titulo     string
		sospechoso bool
	}{
		{"Smells Like Teen Spirit (Acoustic Guitar Karaoke Version)", true},
		{"Bohemian Rhapsody in Bossa Nova Style [Reimagined By AI - Not Real]", true},
		{"Full Instrumental Cover by Wergop99", true},
		{"Made Famous By Queen", true},
		{"Discover the Light", false},
		{"Coverage", false},
		{"Da Funk", false},
		{"So What", false},
	}
	for _, caso := range casos {
		if got := esTituloSospechoso(caso.titulo); got != caso.sospechoso {
			t.Errorf("esTituloSospechoso(%q) = %v, esperaba %v",
				caso.titulo, got, caso.sospechoso)
		}
	}
}

// TestLaConsultaExcluyeRadioYPodcast verifica que el filtro viaje en la
// consulta al índice. Medido contra la API real: sin esto, buscar una canción
// devolvía el programa de radio que se LLAMA como ella.
func TestLaConsultaExcluyeRadioYPodcast(t *testing.T) {
	var consultas []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/advancedsearch.php") {
			consultas = append(consultas, r.URL.Query().Get("q"))
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write([]byte(`{"response":{"numFound":0,"docs":[]}}`))
			return
		}
		w.WriteHeader(http.StatusNotFound)
	}))
	defer srv.Close()

	c := NewClient(nil)
	c.SetBaseURL(srv.URL)
	if _, err := c.SearchTracks("smells like teen spirit nirvana", 10); err != nil {
		t.Fatalf("SearchTracks: %v", err)
	}
	if len(consultas) == 0 {
		t.Fatal("no se consultó al índice")
	}
	q := consultas[0]
	for _, esperado := range []string{"-collection:podcasts", "-collection:radioprograms", "-collection:fmradioarchive"} {
		if !strings.Contains(q, esperado) {
			t.Errorf("la consulta no excluye la colección %q:\n%s", esperado, q)
		}
	}
}

// TestKaraokeVaAlFinal comprueba el orden: si el índice devuelve primero un
// karaoke y después la grabación limpia, la limpia gana el primer puesto —el
// karaoke queda disponible, pero no le roba el lugar a la canción.
func TestKaraokeVaAlFinal(t *testing.T) {
	karaoke := itemConFlac("karaoke-1", "Smells Like Teen Spirit Karaoke", "Karaoke Hits")
	karaoke.Files = []Archivo{{
		Name: "nsp.mp3", Format: "VBR MP3", Track: "1", Length: "301.0",
		Title: "Smells Like Teen Spirit - Nirvana (Acoustic Guitar Karaoke Version).mp3",
	}}
	buena := itemConFlac("buena-1", "Nevermind", "Nirvana")
	buena.Files = []Archivo{{
		Name: "nsp.flac", Format: "Flac", Track: "1", Length: "301.0",
		Title: "Smells Like Teen Spirit",
	}}

	srv, _ := servidorFalso(t,
		[]docItem{
			{Identifier: "karaoke-1", Title: "Smells Like Teen Spirit Karaoke", Creator: "Karaoke Hits"},
			{Identifier: "buena-1", Title: "Nevermind", Creator: "Nirvana"},
		},
		map[string]Item{"karaoke-1": karaoke, "buena-1": buena})

	c := NewClient(nil)
	c.SetBaseURL(srv.URL)

	pistas, err := c.SearchTracks("smells like teen spirit nirvana", 10)
	if err != nil {
		t.Fatalf("SearchTracks: %v", err)
	}
	if len(pistas) != 2 {
		t.Fatalf("esperaba 2 pistas (no se descarta el karaoke), obtuve %d: %+v", len(pistas), pistas)
	}
	if pistas[0].Title != "Smells Like Teen Spirit" {
		t.Errorf("la primera pista debía ser la limpia, fue %q", pistas[0].Title)
	}
	if !strings.Contains(pistas[1].Title, "Karaoke") {
		t.Errorf("el karaoke debía quedar al final, fue %q", pistas[1].Title)
	}
}
