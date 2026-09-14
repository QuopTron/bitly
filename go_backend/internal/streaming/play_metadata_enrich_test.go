package streaming

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/deezer"
)

// EL ESLABÓN QUE ESTE TEST FIJA
// Las fuentes que dan el audio lossless sin sesión (YouTube Music, SoundCloud,
// Internet Archive, Soulseek) NO publican ISRC: no existe en su metadata ni en
// su protocolo. El ISRC se TRADUCE desde el id del video con enrichTrack()
// (SongLink/Odesli) y, si eso no alcanza, se deriva por búsqueda verificada. Sin
// la traducción por identidad, un track de YouTube llegaba a la reproducción sin
// ISRC aunque la grabación tuviera uno, y el rescate lossless quedaba fuera.

func TestAplicarEnriquecimientoNoPisaLoQueYaHay(t *testing.T) {
	track := &provider.TrackResult{
		ID:       "abc123",
		ISRC:     "USRC17607839", // la fuente ya lo traía
		DeezerID: "deezer-propio",
	}
	aplicarEnriquecimiento(track, &provider.EnrichTrackResult{
		ISRC:      "OTRO00000000",
		DeezerID:  "deezer-de-songlink",
		TidalID:   "tidal-123",
		QobuzID:   "qobuz-456",
		SpotifyID: "spotify-789",
	})

	if track.ISRC != "USRC17607839" {
		t.Errorf("el ISRC original se pisó: %q", track.ISRC)
	}
	if track.DeezerID != "deezer-propio" {
		t.Errorf("el DeezerID original se pisó: %q", track.DeezerID)
	}
	// Lo que FALTABA sí se completa: eso es lo que habilita la fase exacta y el
	// rescate FLAC por ISRC.
	if track.TidalID != "tidal-123" || track.QobuzID != "qobuz-456" || track.SpotifyID != "spotify-789" {
		t.Errorf("no se completaron los ids que faltaban: %+v", track)
	}
}

func TestAplicarEnriquecimientoLlenaElISRCQueFaltaba(t *testing.T) {
	track := &provider.TrackResult{ID: "abc123", Title: "One More Time", Artist: "Daft Punk"}
	aplicarEnriquecimiento(track, &provider.EnrichTrackResult{ISRC: "GBDUW0000059"})
	if track.ISRC != "GBDUW0000059" {
		t.Errorf("ISRC = %q, quería el traducido por identidad", track.ISRC)
	}
}

func TestAplicarEnriquecimientoEsToleranteANil(t *testing.T) {
	// Nunca debe romper la reproducción: el enriquecimiento es un extra.
	aplicarEnriquecimiento(nil, &provider.EnrichTrackResult{ISRC: "X"})
	track := &provider.TrackResult{ID: "1"}
	aplicarEnriquecimiento(track, nil)
	if track.ISRC != "" {
		t.Errorf("con enriquecimiento nil no debía cambiar nada: %+v", track)
	}
}

func TestEnriquecimientoVacio(t *testing.T) {
	if !enriquecimientoVacio(nil) {
		t.Error("nil debe contar como vacío")
	}
	if !enriquecimientoVacio(&provider.EnrichTrackResult{}) {
		t.Error("sin datos debe contar como vacío")
	}
	if !enriquecimientoVacio(&provider.EnrichTrackResult{ISRC: "   "}) {
		t.Error("solo espacios debe contar como vacío")
	}
	if enriquecimientoVacio(&provider.EnrichTrackResult{TidalID: "1"}) {
		t.Error("con un id debe contar como útil")
	}
}

func TestEnriquecerPorIdentidadNoLlamaAUnCatalogo(t *testing.T) {
	// Deezer es un cliente nativo, NO una extensión con enrichTrack: no debe
	// intentar nada (y menos aún tocar la red). Es el caso de todas las fuentes
	// que ya publican ISRC.
	reg := provider.NewRegistry()
	reg.Register(deezer.NewClient(nil))

	if got := enriquecerPorIdentidad(reg, "deezer", "123", "Tema"); got != nil {
		t.Errorf("un catálogo sin enrichTrack no debe enriquecer: %+v", got)
	}
	if got := enriquecerPorIdentidad(nil, "deezer", "123", "Tema"); got != nil {
		t.Errorf("registro nil no debe enriquecer: %+v", got)
	}
	if got := enriquecerPorIdentidad(reg, "inexistente", "123", "Tema"); got != nil {
		t.Errorf("proveedor inexistente no debe enriquecer: %+v", got)
	}
	// Sin id no hay nada que traducir: la extensión necesita el id del video.
	if got := enriquecerPorIdentidad(reg, "deezer", "", "Tema"); got != nil {
		t.Errorf("sin id no debe enriquecer: %+v", got)
	}
}
