package streaming

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// verifStubProvider devuelve un registro fijo y un stream controlable, para
// probar la verificación y el orden de fuentes sin tocar la red.
type verifStubProvider struct {
	name    string
	track   *provider.TrackResult
	resolve func() (string, error)
}

func (s *verifStubProvider) Name() string { return s.name }
func (s *verifStubProvider) SearchTracks(q string, l int) ([]provider.TrackResult, error) {
	return nil, nil
}
func (s *verifStubProvider) SearchAlbums(q string, l int) ([]provider.AlbumResult, error) {
	return nil, nil
}
func (s *verifStubProvider) SearchArtists(q string, l int) ([]provider.ArtistResult, error) {
	return nil, nil
}
func (s *verifStubProvider) SearchPlaylists(q string, l int) ([]provider.PlaylistResult, error) {
	return nil, nil
}
func (s *verifStubProvider) GetTrack(id string) (*provider.TrackResult, error) { return s.track, nil }
func (s *verifStubProvider) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	return nil, nil
}
func (s *verifStubProvider) GetAlbum(id string) (*provider.AlbumResult, error)   { return nil, nil }
func (s *verifStubProvider) GetArtist(id string) (*provider.ArtistResult, error) { return nil, nil }
func (s *verifStubProvider) GetStreamURL(id, quality string) (string, error) {
	if s.resolve == nil {
		return "", nil
	}
	return s.resolve()
}

// Política de fuentes de audio: los catálogos BUSCAN, no streamean. Solo
// YouTube (sí o sí) y —si se pidió sin pérdida— Internet Archive / Soulseek /
// flac-rescue pueden aportar audio. Antes la carrera metía a
// spotify-web/qobuz-web/tidal-web/amazon/apple-music, que sin sesión firmada no
// pueden resolver una URL: ocupaban un turno del pool para devolver nada y
// retrasaban el turno del re-subido que sí tenía el audio.
func TestFuentesDeAudioExcluyenCatalogosDeBusqueda(t *testing.T) {
	// Ninguna fuente de solo-búsqueda puede ser fuente de audio.
	soloBusqueda := []string{
		"spotify-web", "spotify", "deezer", "deezer-web", "qobuz", "qobuz-web",
		"tidal", "tidal-web", "amazon", "amazon-web", "apple-music", "apple",
		"pandora", "musicbrainz", "redacted",
	}
	for _, n := range soloBusqueda {
		if contieneNombre(proveedoresAudio, n) {
			t.Errorf("%q solo sirve para buscar: no puede ser fuente de audio", n)
		}
		if esProviderStreaming(n) {
			t.Errorf("esProviderStreaming(%q) = true; el catálogo no streamea", n)
		}
	}

	// YouTube es la fuente de audio obligatoria, y va primero.
	if !contieneNombre(proveedoresAudio, "ytmusic-spotiflac") ||
		!contieneNombre(proveedoresAudio, "youtube") {
		t.Fatal("ytmusic-spotiflac y youtube deben ser fuentes de audio")
	}
	if proveedoresAudio[0] != "ytmusic-spotiflac" {
		t.Fatalf("ytmusic-spotiflac debe reclamar el primer turno; es %q", proveedoresAudio[0])
	}
	// Y el FLAC real cuando se pidió sin pérdida.
	for _, n := range []string{"internetarchive", "soulseek", "flac-rescue"} {
		if !contieneNombre(proveedoresAudio, n) {
			t.Errorf("%q debe ser fuente de audio (FLAC sin sesión)", n)
		}
	}

	// Ningún re-subido puede estar entre las fuentes exactas.
	for _, n := range proveedoresExactos {
		if esProveedorReSubido(n) {
			t.Fatalf("%q es un re-subido y no puede estar en proveedoresExactos", n)
		}
		if contieneNombre(soloBusqueda, n) {
			t.Fatalf("%q no entrega audio sin sesión: fuera de proveedoresExactos", n)
		}
	}
	// flac-rescue se queda: su índice ES el ISRC, así que resuelve por identidad.
	if !contieneNombre(proveedoresExactos, "flac-rescue") {
		t.Fatal("proveedoresExactos debe incluir flac-rescue (índice por ISRC)")
	}

	// Todo lo que está en proveedoresReSubidos tiene que clasificar como tal.
	for _, n := range proveedoresReSubidos {
		if !esProveedorReSubido(n) {
			t.Fatalf("esProveedorReSubido(%q) = false", n)
		}
	}
	if !esProveedorReSubido("soundcloud") || !esProveedorReSubido("ytmusic-spotiflac") {
		t.Fatal("soundcloud e ytmusic-spotiflac deben clasificar como re-subidos")
	}
	if esProveedorReSubido("deezer") {
		t.Fatal("deezer no es un re-subido")
	}
}

func contieneNombre(nombres []string, buscado string) bool {
	for _, n := range nombres {
		if n == buscado {
			return true
		}
	}
	return false
}

// Regresión del bug reportado: la fuente EXACTA es más lenta que el re-subido y
// aun así debe ganar. Antes una sola carrera paralela dejaba ganar al primero
// que respondía (YouTube), sirviendo un re-subido/remix de la misma canción.
func TestCarreraPorConfianzaPrefiereFuenteExacta(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&verifStubProvider{name: "deezer", resolve: func() (string, error) {
		time.Sleep(250 * time.Millisecond)
		return "http://deezer/exacto", nil
	}})
	reg.Register(&verifStubProvider{name: "ytmusic-spotiflac", resolve: func() (string, error) {
		return "http://ytmusic/resubido", nil
	}})

	url, name, verified := carreraPorConfianza(reg,
		[]string{"ytmusic-spotiflac", "deezer"}, 5*time.Second, 2,
		func(n string, p provider.Provider) (string, bool) {
			u, err := p.GetStreamURL(n, "high")
			if err != nil || u == "" {
				return "", false
			}
			return u, false
		})

	if verified {
		t.Fatalf("no debía pedir verificación, devolvió verify=%v", verified)
	}
	if url != "http://deezer/exacto" || name != "deezer" {
		t.Fatalf("ganó %q de %q; la fuente exacta debía ganar al re-subido", url, name)
	}
}

// Si NINGUNA fuente exacta puede servir, el re-subido sigue sirviendo: una
// canción sonando (aunque sea un re-subido) es mejor que un fallo.
func TestCarreraPorConfianzaCaeAResubido(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&verifStubProvider{name: "deezer", resolve: func() (string, error) {
		return "", nil
	}})
	reg.Register(&verifStubProvider{name: "soundcloud", resolve: func() (string, error) {
		return "http://soundcloud/resubido", nil
	}})

	url, name, _ := carreraPorConfianza(reg,
		[]string{"soundcloud", "deezer"}, 5*time.Second, 2,
		func(n string, p provider.Provider) (string, bool) {
			u, err := p.GetStreamURL(n, "high")
			if err != nil || u == "" {
				return "", false
			}
			return u, false
		})

	if url != "http://soundcloud/resubido" || name != "soundcloud" {
		t.Fatalf("debió caer al re-subido, got %q de %q", url, name)
	}
}

// Un re-subido NO puede confirmar la identidad solo porque "declare" el ISRC:
// ese ISRC lo infiere por parecido de nombre, así que un remix con el mismo
// título recibía el ISRC del original y se servía como si fuera la canción.
func TestVerificarMatchStreamReSubidoNoSeAceptaSoloPorISRC(t *testing.T) {
	const isrc = "USRC17607839"
	// SoundCloud: título que NO es la canción pedida y un ISRC "declarado".
	sc := &verifStubProvider{name: "soundcloud", track: &provider.TrackResult{
		ID: "1", Title: "Otro Remix Random", Artist: "Dj Random", ISRC: isrc,
	}}
	if got := verificarMatchStream(sc, "1", "Mi Cancion", "Artista Real", isrc, true); got != "" {
		t.Fatalf("verificarMatchStream aceptó un re-subido por el ISRC: %q", got)
	}
}

// El rescate indexado por ISRC (flac-rescue) no tiene catálogo: su título es el
// ISRC. Debe aceptarse como la grabación exacta (antes se rechazaba y el rescate
// FLAC por ISRC nunca llegaba a reproducir).
func TestVerificarMatchStreamAceptaRescatePorISRC(t *testing.T) {
	const isrc = "USRC17607839"
	fr := &verifStubProvider{name: "flac-rescue", track: &provider.TrackResult{
		ID: isrc, Title: isrc, ISRC: isrc, Provider: "flac-rescue",
	}}
	if got := verificarMatchStream(fr, isrc, "Mi Cancion", "Artista Real", isrc, true); got != isrc {
		t.Fatalf("verificarMatchStream rechazó el rescate por ISRC: %q", got)
	}
}

// Un ISRC distinto es identidad distinta: se rechaza siempre.
func TestVerificarMatchStreamISRCDistinto(t *testing.T) {
	deezer := &verifStubProvider{name: "deezer", track: &provider.TrackResult{
		ID: "1", Title: "Mi Cancion", Artist: "Artista Real", ISRC: "OTRO0000001",
	}}
	if got := verificarMatchStream(deezer, "1", "Mi Cancion", "Artista Real", "USRC17607839", true); got != "" {
		t.Fatalf("verificarMatchStream aceptó un ISRC distinto: %q", got)
	}
}

// Un catálogo con el mismo ISRC confirma la grabación aunque el título difiera
// en la forma (sufijos/versión): ahí el ISRC viene del sello.
func TestVerificarMatchStreamCatalogoConMismoISRC(t *testing.T) {
	const isrc = "USRC17607839"
	deezer := &verifStubProvider{name: "deezer", track: &provider.TrackResult{
		ID: "1", Title: "Mi Cancion (Album Version)", Artist: "Artista Real", ISRC: isrc,
	}}
	if got := verificarMatchStream(deezer, "1", "Mi Cancion", "Artista Real", isrc, true); got != "1" {
		t.Fatalf("verificarMatchStream rechazó un catálogo con el ISRC exacto: %q", got)
	}
}
