package provider

import (
	"sync"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
)

// isrcMockProvider devuelve lo que el test le diga; cuenta las búsquedas para
// poder afirmar que la caché evita repetirlas y puede demorar la respuesta para
// pinchar el paralelismo de la derivación.
type isrcMockProvider struct {
	name     string
	results  []TrackResult
	llamadas *int
	demora   time.Duration
}

func (m *isrcMockProvider) Name() string { return m.name }
func (m *isrcMockProvider) SearchTracks(q string, l int) ([]TrackResult, error) {
	*m.llamadas++
	if m.demora > 0 {
		time.Sleep(m.demora)
	}
	return m.results, nil
}
func (m *isrcMockProvider) SearchAlbums(q string, l int) ([]AlbumResult, error)   { return nil, nil }
func (m *isrcMockProvider) SearchArtists(q string, l int) ([]ArtistResult, error) { return nil, nil }
func (m *isrcMockProvider) SearchPlaylists(q string, l int) ([]PlaylistResult, error) {
	return nil, nil
}
func (m *isrcMockProvider) GetTrack(id string) (*TrackResult, error)      { return nil, nil }
func (m *isrcMockProvider) GetTrackByISRC(i string) (*TrackResult, error) { return nil, nil }
func (m *isrcMockProvider) GetAlbum(id string) (*AlbumResult, error)      { return nil, nil }
func (m *isrcMockProvider) GetArtist(id string) (*ArtistResult, error)    { return nil, nil }
func (m *isrcMockProvider) GetStreamURL(id, q string) (string, error)     { return "", nil }

func registroConISRC(id string, results []TrackResult, llamadas *int) *Registry {
	r := NewRegistry()
	r.Register(&isrcMockProvider{name: id, results: results, llamadas: llamadas})
	return r
}

func TestDerivarISRC_OriginalConDuracionCompatible(t *testing.T) {
	var llamadas int
	// El candidato es el original exacto y dura casi lo mismo: ISRC válido.
	r := registroConISRC("deezer", []TrackResult{
		{ID: "1", Title: "Titulo Unico Derivar", Artist: "Artista Unico", Duration: 200000, ISRC: "USRC17607839"},
	}, &llamadas)

	got := DerivarISRC(r, "Titulo Unico Derivar", "Artista Unico", 201000)
	if got != "USRC17607839" {
		t.Fatalf("DerivarISRC = %q, quería el ISRC del original", got)
	}
}

func TestDerivarISRC_RechazaRemixYArtistaEquivocado(t *testing.T) {
	var llamadas int
	// Un remix y una cover (artista distinto): ninguno sirve para derivar.
	r := registroConISRC("deezer", []TrackResult{
		{ID: "1", Title: "Otro Titulo (Remix)", Artist: "Otro Artista", Duration: 200000, ISRC: "REMEZ0000001"},
		{ID: "2", Title: "Otro Titulo", Artist: "Cover Band", Duration: 200000, ISRC: "COVER0000001"},
	}, &llamadas)

	if got := DerivarISRC(r, "Otro Titulo", "Artista Real", 200000); got != "" {
		t.Fatalf("DerivarISRC = %q, no debía derivar de un remix/cover", got)
	}
}

func TestDerivarISRC_RechazaDuracionMuyDistinta(t *testing.T) {
	var llamadas int
	// Mismo título y artista, pero 5 minutos vs 2: es OTRA toma, no se deriva.
	r := registroConISRC("deezer", []TrackResult{
		{ID: "1", Title: "Cancion Larga Unica", Artist: "Artista Largo", Duration: 300000, ISRC: "LARGA0000001"},
	}, &llamadas)

	if got := DerivarISRC(r, "Cancion Larga Unica", "Artista Largo", 120000); got != "" {
		t.Fatalf("DerivarISRC = %q, no debía aceptar una duración incompatible", got)
	}
}

func TestDerivarISRC_CacheaAciertosYFallos(t *testing.T) {
	var llamadas int
	r := registroConISRC("deezer", []TrackResult{
		{ID: "1", Title: "Cache Titulo", Artist: "Cache Artista", Duration: 180000, ISRC: "CACHE0000001"},
	}, &llamadas)

	if got := DerivarISRC(r, "Cache Titulo", "Cache Artista", 180000); got != "CACHE0000001" {
		t.Fatalf("primer llamado = %q", got)
	}
	DerivarISRC(r, "Cache Titulo", "Cache Artista", 180000)
	if llamadas != 1 {
		t.Fatalf("el 2do llamado debía salir del caché: hubo %d búsquedas", llamadas)
	}

	// Negativo: también se cachea, para no repetir la búsqueda en cada tap.
	var vacio int
	rVacio := registroConISRC("deezer", nil, &vacio)
	DerivarISRC(rVacio, "No Existe Titulo", "No Existe Artista", 0)
	DerivarISRC(rVacio, "No Existe Titulo", "No Existe Artista", 0)
	if vacio != 1 {
		t.Fatalf("el fallo debía cachearse: hubo %d búsquedas", vacio)
	}
}

// TestDerivarISRC_UsaMusicBrainzCuandoLosComercialesNoTienen fija la última
// capa de la cadena: MusicBrainz es la única base de ISRC sin cuenta ni sesión
// firmada, y cubre catálogo que los servicios comerciales no tienen (sellos
// independientes, regional, clásica). Sin ella, esos tracks se quedaban sin
// ISRC y perdían el rescate FLAC.
func TestDerivarISRC_UsaMusicBrainzCuandoLosComercialesNoTienen(t *testing.T) {
	var llamadas int
	r := registroConISRC("musicbrainz", []TrackResult{
		{ID: "mb-1", Title: "Tema Indie Unico", Artist: "Banda Indie Unica", Duration: 210000, ISRC: "QZIND0000001"},
	}, &llamadas)

	got := DerivarISRC(r, "Tema Indie Unico", "Banda Indie Unica", 210000)
	if got != "QZIND0000001" {
		t.Fatalf("DerivarISRC = %q, quería el ISRC de MusicBrainz", got)
	}
	if llamadas == 0 {
		t.Error("no se consultó MusicBrainz")
	}
}

// TestProveedoresConISRCMusicBrainzVaAlFinal: su API limita a 1 request por
// segundo, así que se consulta DESPUÉS de los catálogos rápidos; el presupuesto
// de 4s acota la espera.
func TestProveedoresConISRCMusicBrainzVaAlFinal(t *testing.T) {
	if len(proveedoresConISRC) == 0 {
		t.Fatal("la cadena de derivación está vacía")
	}
	ultimo := proveedoresConISRC[len(proveedoresConISRC)-1]
	if ultimo != "musicbrainz" {
		t.Errorf("el último proveedor es %q, quería musicbrainz (1 req/s)", ultimo)
	}
}

// TestDerivarISRCNoSeQuedaSinMusicBrainzPorUnCatalogoLento fija el arreglo del
// bug de fiabilidad: con el recorrido SERIE, un primer catálogo que tarda (o
// gasta su timeout) agotaba el presupuesto de 4s y MusicBrainz —la única base
// de ISRC sin cuenta— NUNCA se consultaba, así que el track quedaba sin ISRC y
// perdía la fase exacta y el rescate FLAC. En paralelo, el catálogo que responde
// habilita el ISRC sin esperar al lento.
func TestDerivarISRCNoSeQuedaSinMusicBrainzPorUnCatalogoLento(t *testing.T) {
	cooldown.MarkOk("deezer")
	cooldown.MarkOk("musicbrainz")
	var lento, rapido int
	r := NewRegistry()
	// El catálogo preferido (primero en la lista) responde bien después del
	// presupuesto: en serie, su turno se comía la ventana entera.
	r.Register(&isrcMockProvider{
		name:     "deezer",
		demora:   presupuestoDerivarISRC + time.Second,
		llamadas: &lento,
	})
	r.Register(&isrcMockProvider{
		name: "musicbrainz",
		results: []TrackResult{
			{ID: "mb-1", Title: "Tema Paralelo Unico", Artist: "Banda Paralela", Duration: 200000, ISRC: "QZPAR0000001"},
		},
		llamadas: &rapido,
	})

	inicio := time.Now()
	got := DerivarISRC(r, "Tema Paralelo Unico", "Banda Paralela", 200000)
	tardanza := time.Since(inicio)
	if got != "QZPAR0000001" {
		t.Fatalf("DerivarISRC = %q, quería el ISRC del catálogo que sí respondió", got)
	}
	if rapido == 0 {
		t.Fatal("MusicBrainz no fue consultado")
	}
	// No se espera al lento: se devuelve apenas responde el que tiene el dato
	// (más la ventana corta de orden).
	if tardanza >= presupuestoDerivarISRC {
		t.Fatalf("la derivación esperó %s: se quedó esperando al catálogo lento", tardanza)
	}
}

// TestDerivarISRCClaveIncluyeDuracion: dos TOMAS distintas de la misma canción
// (mismo título y artista, otra duración) no pueden compartir la entrada de
// caché — con la clave vieja la segunda recibía el ISRC de la primera, que es
// exactamente la identidad equivocada que la derivación existe para evitar.
func TestDerivarISRCClaveIncluyeDuracion(t *testing.T) {
	var llamadas int
	r := registroConISRC("deezer", []TrackResult{
		{ID: "1", Title: "Tema Dos Tomas", Artist: "Artista Dos Tomas", Duration: 200000, ISRC: "ORIG00000001"},
	}, &llamadas)

	if got := DerivarISRC(r, "Tema Dos Tomas", "Artista Dos Tomas", 200000); got != "ORIG00000001" {
		t.Fatalf("primera toma = %q", got)
	}
	// La versión extendida/directo dura 6 minutos: otra toma, otra entrada.
	if got := DerivarISRC(r, "Tema Dos Tomas", "Artista Dos Tomas", 360000); got == "ORIG00000001" {
		t.Fatalf("la segunda toma reusó el ISRC de la primera: %q", got)
	}
	if llamadas < 2 {
		t.Fatalf("la segunda duración debía volver a buscar: hubo %d búsquedas", llamadas)
	}
}

// TestDerivarISRCComparteElRecorridoEnVuelo: dos derivaciones idénticas que
// corren a la vez — dentro de UN pedido el rescate y el canal sin pérdida
// disparan la misma (ver streaming/rescue_stream.go y
// gobackend/stream_package_lossless.go)— pagan UN solo recorrido de catálogos.
// Cada recorrido consulta todos los catálogos con ISRC en paralelo, así que el
// duplicado eran dos baterías de búsquedas (y dos veces los 429) por canción.
func TestDerivarISRCComparteElRecorridoEnVuelo(t *testing.T) {
	cooldown.MarkOk("deezer")

	var llamadas int
	r := NewRegistry()
	r.Register(&isrcMockProvider{
		name: "deezer",
		results: []TrackResult{
			{ID: "1", Title: "Tema Compartido", Artist: "Artista Compartido", Duration: 200000, ISRC: "COMP00000001"},
		},
		llamadas: &llamadas,
		demora:   200 * time.Millisecond,
	})

	var wg sync.WaitGroup
	isrcs := make([]string, 2)
	for i := range isrcs {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			isrcs[i] = DerivarISRC(r, "Tema Compartido", "Artista Compartido", 201000)
		}(i)
	}
	wg.Wait()

	for i, got := range isrcs {
		if got != "COMP00000001" {
			t.Errorf("derivación %d = %q, quería el ISRC del original", i, got)
		}
	}
	if llamadas != 1 {
		t.Errorf("catálogo consultado %d veces con dos derivaciones idénticas en vuelo, se esperaba 1", llamadas)
	}
}

func TestDuracionCompatible(t *testing.T) {
	casos := []struct {
		query, got int
		want       bool
	}{
		{200000, 201000, true},
		{200000, 0, true},       // candidato sin duración: no se puede verificar
		{0, 200000, true},       // consulta sin duración
		{200000, 240000, true},  // 40s < 50s (25%)
		{200000, 260000, false}, // 60s > 50s
		{20000, 60000, false},   // tolerancia mínima de 20s se queda corta
	}
	for _, c := range casos {
		if got := duracionCompatible(c.query, c.got); got != c.want {
			t.Errorf("duracionCompatible(%d,%d) = %v, want %v", c.query, c.got, got, c.want)
		}
	}
}
