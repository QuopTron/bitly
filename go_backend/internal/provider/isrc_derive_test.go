package provider

import "testing"

// isrcMockProvider devuelve lo que el test le diga; cuenta las búsquedas para
// poder afirmar que la caché evita repetirlas.
type isrcMockProvider struct {
	name     string
	results  []TrackResult
	llamadas *int
}

func (m *isrcMockProvider) Name() string { return m.name }
func (m *isrcMockProvider) SearchTracks(q string, l int) ([]TrackResult, error) {
	*m.llamadas++
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
