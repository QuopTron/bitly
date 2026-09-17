package gobackend

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider/lastfm"
)

// El rescate de búsqueda solo puede aportar pistas REPRODUCIBLES: el audio
// sale de YouTube, así que una pista sin video oficial no sirve y se descarta.
func TestItemsDePistasCanonicas(t *testing.T) {
	pistas := []lastfm.Pista{
		{Nombre: "NUEVAYoL", Artistas: "Bad Bunny", DuracionMs: 182000, YouTubeID: "KU5V5WZVcVE"},
		{Nombre: "Sin video", Artistas: "X", YouTubeID: ""},
		{Nombre: "Id corto", Artistas: "X", YouTubeID: "abc"},
		{Nombre: "", Artistas: "X", YouTubeID: "v9T_MGfzq7I"},
		{Nombre: "DtMF", Artistas: "Bad Bunny", DuracionMs: 236000, YouTubeID: "v9T_MGfzq7I"},
	}
	items := itemsDePistasCanonicas(pistas)
	if len(items) != 2 {
		t.Fatalf("esperaba 2 items reproducibles, obtuve %d: %+v", len(items), items)
	}
	if items[0].ID != "yt:KU5V5WZVcVE" {
		t.Errorf("el id debe llevar el prefijo del proveedor de YouTube: %q", items[0].ID)
	}
	if items[0].Type != "track" || items[0].Source != "youtube" {
		t.Errorf("item mal armado: %+v", items[0])
	}
	if items[0].DurationMs != 182000 {
		t.Errorf("la duración del sitio debe viajar al item (rompe el match por duración): %d", items[0].DurationMs)
	}
}

// El rescate no puede inundar la lista: son el arranque, no el catálogo.
func TestItemsDePistasCanonicasAcotado(t *testing.T) {
	pistas := make([]lastfm.Pista, 0, 20)
	for i := 0; i < 20; i++ {
		pistas = append(pistas, lastfm.Pista{Nombre: "t", YouTubeID: "KU5V5WZVcVE"})
	}
	if got := len(itemsDePistasCanonicas(pistas)); got != maxRescateLastfm {
		t.Errorf("esperaba %d items como máximo, obtuve %d", maxRescateLastfm, got)
	}
}

// Solo tiene sentido rescatar temas concretos: una consulta de álbumes o
// artistas no se arregla con una pista suelta.
func TestTipoBuscaCanciones(t *testing.T) {
	for _, si := range []string{"", "all", "track", "tracks", "song", "songs", "ALL"} {
		if !tipoBuscaCanciones(si) {
			t.Errorf("%q debe habilitar el rescate de canciones", si)
		}
	}
	for _, no := range []string{"album", "albums", "artist", "artists", "playlist", "playlists"} {
		if tipoBuscaCanciones(no) {
			t.Errorf("%q NO debe habilitar el rescate de canciones", no)
		}
	}
}

// Sin consulta util no hay nada que rescatar (una búsqueda de 1-2 letras trae
// cualquier cosa del sitio).
func TestReforzarBusquedaNoHaceNadaSinConsulta(t *testing.T) {
	for _, q := range []string{"", " ", "ab"} {
		reforzarBusquedaConLastfm(currentSearchStream.generation+1, q, "", "all")
	}
}
