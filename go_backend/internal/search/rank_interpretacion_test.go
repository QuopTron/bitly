// rank_interpretacion_test.go — Regresión del caso que reporta el usuario:
// buscar un nombre comercial ("bad bunny monaco") servía covers y re-subidas en
// vez de la grabación real.
//
// Por qué existía: una consulta SIN separador se leía entera como título, así
// que un cover literalmente titulado "Bad Bunny Monaco" (de otro artista)
// conseguía coincidencia exacta de título (+50) y el "MONACO" real de Bad Bunny
// solo contención (+40) sin crédito de artista. Puntajes reales medidos con el
// ranker viejo: cover 90, grabación real 80.
//
// Se conecta con: rank.go (lecturas de la consulta y puntaje).
// Parte del flujo: búsqueda multi-fuente.
package search

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// grabacionReal es el "MONACO" de Bad Bunny tal como lo devuelve Deezer
// (medido contra la API real: ISRC QMFME2364182, 267 s).
func grabacionReal() provider.TrackResult {
	return provider.TrackResult{
		ID: "deezer:1", Title: "MONACO", Artist: "Bad Bunny",
		ISRC: "QMFME2364182", Duration: 267000,
		CoverURL: "https://cover/deezer/1", Provider: "deezer",
	}
}

// coverAjeno es el cover real que Deezer devuelve segundo para la misma
// consulta: otra canción, 67 s, artista distinto, con el nombre del artista
// querido metido en el título.
func coverAjeno() provider.TrackResult {
	return provider.TrackResult{
		ID: "deezer:2", Title: "Bad Bunny Monaco", Artist: "Lee Sang Gul",
		ISRC: "FRX762408732", Duration: 67000,
		CoverURL: "https://cover/deezer/2", Provider: "deezer",
	}
}

// TestConsultaSinSeparadorPrefiereLaGrabacionReal fija el caso exacto del
// usuario: "bad bunny monaco" debe ordenar la grabación real por encima del
// cover que repite el nombre del artista en el título.
func TestConsultaSinSeparadorPrefiereLaGrabacionReal(t *testing.T) {
	r := newRanker("bad bunny monaco")

	real := r.score(grabacionReal())
	cover := r.score(coverAjeno())

	if real <= cover {
		t.Errorf("la grabación real (%f) debe superar al cover (%f)", real, cover)
	}
}

// TestResubidaQuedaPorDebajoDeLaGrabacionReal cubre la otra mitad del reporte
// ("artistas que resuben"): una re-subida de YouTube/SoundCloud del mismo tema
// no puede ganarle a la entrada que tiene crédito de artista.
func TestResubidaQuedaPorDebajoDeLaGrabacionReal(t *testing.T) {
	r := newRanker("bad bunny monaco")

	real := r.score(grabacionReal())
	resubida := provider.TrackResult{
		ID: "sc:1", Title: "Bad Bunny - Monaco (Official Audio)",
		Artist: "Bad Bunny Topic", Provider: "soundcloud",
	}
	remix := provider.TrackResult{
		ID: "yt:1", Title: "Bad Bunny - Monaco (Remix)",
		Artist: "DJ Algo", Provider: "youtube",
	}

	if real <= r.score(resubida) {
		t.Errorf("la grabación real (%f) debe superar a la re-subida (%f)", real, r.score(resubida))
	}
	if real <= r.score(remix) {
		t.Errorf("la grabación real (%f) debe superar al remix (%f)", real, r.score(remix))
	}
}

// TestOrdenArtistaAlFinal busca al revés ("título artista"): la lectura como
// título + artista tiene que existir, no solo la de artista + título.
func TestOrdenArtistaAlFinal(t *testing.T) {
	r := newRanker("bohemian rhapsody queen")

	correcto := provider.TrackResult{
		ID: "deezer:1", Title: "Bohemian Rhapsody", Artist: "Queen",
		ISRC: "GBUM71029604", Duration: 355000, Provider: "deezer",
	}
	// Otra canción que solo comparte el nombre del artista en el título.
	ajeno := provider.TrackResult{
		ID: "deezer:2", Title: "Queen Bohemian Rhapsody", Artist: "Some Band",
		ISRC: "XX0000000001", Duration: 200000, Provider: "deezer",
	}

	if r.score(correcto) <= r.score(ajeno) {
		t.Errorf("la grabación correcta (%f) debe superar al homónimo (%f)",
			r.score(correcto), r.score(ajeno))
	}
}

// TestConsultaConSeparadorNoCambia verifica que el camino ya existente (con
// separador explícito) siga con una sola lectura y el mismo puntaje alto.
func TestConsultaConSeparadorNoCambia(t *testing.T) {
	r := newRanker("Bad Bunny - MONACO")
	if len(r.interpretaciones) != 1 {
		t.Fatalf("una consulta con separador debe tener 1 lectura, tiene %d", len(r.interpretaciones))
	}
	if s := r.score(grabacionReal()); s < 90 {
		t.Errorf("con separador la grabación real debe puntuar alto, puntuó %f", s)
	}
}

// TestLongitudDeConsultasLargas acota el costo: una consulta larga no puede
// generar lecturas sin freno.
func TestLongitudDeConsultasLargas(t *testing.T) {
	r := newRanker("uno dos tres cuatro cinco seis siete ocho nueve diez")
	if len(r.interpretaciones) > maxInterpretaciones {
		t.Errorf("lecturas = %d, máximo %d", len(r.interpretaciones), maxInterpretaciones)
	}
	if len(r.interpretaciones) == 0 {
		t.Error("una consulta con separadores de espacio debe tener al menos una lectura")
	}
}
