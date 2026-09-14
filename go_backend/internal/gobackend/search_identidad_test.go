package gobackend

import "testing"

func TestNormalizarIdentidad(t *testing.T) {
	casos := map[string]string{
		"One More Time":  "one more time",
		"  Get  Lucky  ": "get lucky",
		"Beyoncé":        "beyonce",
		"Café Tacvba":    "cafe tacvba",
		"AC/DC":          "ac dc",
		"Don't Stop":     "don t stop", // La puntuación se va: los paréntesis los saca quitarRuido antes, en
		// claveNombre; acá solo queda el texto comparable.
		"Tema (Remastered)": "tema remastered",
		"¡Ay!":              "ay",
	}
	for entrada, quiero := range casos {
		if got := normalizarIdentidad(entrada); got != quiero {
			t.Errorf("normalizarIdentidad(%q) = %q, quiero %q", entrada, got, quiero)
		}
	}
}

func TestQuitarRuido(t *testing.T) {
	casos := map[string]string{
		"One More Time":              "One More Time",
		"One More Time (Remastered)": "One More Time",
		"Song [Official Video]":      "Song",
		"Tema (feat. Otro)":          "Tema",
		"Tema - Remastered 2011":     "Tema",
		"Cancion (Live)":             "Cancion (Live)",
		"Tema (En Vivo)":             "Tema (En Vivo)",
	}
	for entrada, quiero := range casos {
		if got := quitarRuido(entrada); got != quiero {
			t.Errorf("quitarRuido(%q) = %q, quiero %q", entrada, got, quiero)
		}
	}
	// Un bloque que NO es ruido y va seguido de uno que sí: solo se va el ruido.
	if got := quitarRuido("Tema (Live) (Remastered)"); got != "Tema (Live)" {
		t.Errorf("quitarRuido mezcló bloques: %q", got)
	}
}

func TestArtistaPrincipalDe(t *testing.T) {
	casos := map[string]string{
		"Daft Punk, Pharrell Williams": "daft punk",
		"Daft Punk & Nile Rodgers":     "daft punk",
		"Daft Punk feat. Pharrell":     "daft punk",
		"Daft Punk ft Pharrell":        "daft punk",
		"Beyoncé":                      "beyonce",
	}
	for entrada, quiero := range casos {
		if got := artistaPrincipalDe(entrada); got != quiero {
			t.Errorf("artistaPrincipalDe(%q) = %q, quiero %q", entrada, got, quiero)
		}
	}
}

func TestEsElMismoTrack(t *testing.T) {
	base := FeedItemGo{Type: "track", Name: "One More Time", Artists: "Daft Punk", DurationMs: 320000}

	// El MISMO tema escrito distinto en dos catálogos (el caso real de
	// "Todas"): uno con coletilla de remaster, otro con artistas de más.
	otro := FeedItemGo{
		Type: "track", Name: "One More Time (Remastered)",
		Artists: "Daft Punk, Pharrell Williams", DurationMs: 320100,
	}
	if !esElMismoTrack(base, otro) {
		t.Error("dos escrituras del mismo tema deberían ser el mismo track")
	}

	// Un radio edit (misma canción, otra duración) NO es el mismo track:
	// colapsarlos escondería una de las dos versiones.
	radio := FeedItemGo{Type: "track", Name: "One More Time", Artists: "Daft Punk", DurationMs: 200000}
	if esElMismoTrack(base, radio) {
		t.Error("un radio edit no es el mismo track que el original")
	}

	// Sin duración en alguno de los dos, el nombre manda.
	sinDur := FeedItemGo{Type: "track", Name: "One More Time", Artists: "Daft Punk"}
	if !esElMismoTrack(base, sinDur) {
		t.Error("sin duración debe compararse por nombre+artista")
	}

	// ISRC en los dos lados: manda el ISRC, aunque el texto difiera.
	a := FeedItemGo{Type: "track", Name: "A", ISRC: "USRC17607839", DurationMs: 1000}
	b := FeedItemGo{Type: "track", Name: "B (Remastered)", ISRC: "usrc17607839", DurationMs: 1000}
	if !esElMismoTrack(a, b) {
		t.Error("mismo ISRC debería ser el mismo track (sin importar mayúsculas)")
	}
	if esElMismoTrack(a, FeedItemGo{Type: "track", Name: "A", ISRC: "ZZZZZZZZZZZZ", DurationMs: 1000}) {
		t.Error("ISRC distinto no es el mismo track")
	}
}

func TestPropagarISRCPrestaElDelOtroCatalogo(t *testing.T) {
	items := []FeedItemGo{
		{Type: "track", Name: "One More Time (Remastered)", Artists: "Daft Punk, Pharrell", DurationMs: 320100},
		{Type: "track", Name: "One More Time", Artists: "Daft Punk", DurationMs: 320000, ISRC: "GBDUW0000059"},
	}
	propagarISRC(items)
	if items[0].ISRC != "GBDUW0000059" {
		t.Errorf("no se prestó el ISRC: %q", items[0].ISRC)
	}

	// Sin duración en alguno de los dos no se presta nada: es el único
	// respaldo cuando no hay ISRC y un ISRC equivocado contamina todo.
	sinDur := []FeedItemGo{
		{Type: "track", Name: "One More Time", Artists: "Daft Punk"},
		{Type: "track", Name: "One More Time", Artists: "Daft Punk", DurationMs: 320000, ISRC: "GBDUW0000059"},
	}
	propagarISRC(sinDur)
	if sinDur[0].ISRC != "" {
		t.Errorf("no debe prestarse ISRC sin duración: %q", sinDur[0].ISRC)
	}

	// Duración claramente distinta: es otra versión, no se presta.
	otraVersion := []FeedItemGo{
		{Type: "track", Name: "One More Time", Artists: "Daft Punk", DurationMs: 200000},
		{Type: "track", Name: "One More Time", Artists: "Daft Punk", DurationMs: 320000, ISRC: "GBDUW0000059"},
	}
	propagarISRC(otraVersion)
	if otraVersion[0].ISRC != "" {
		t.Errorf("no debe prestarse ISRC entre versiones distintas: %q", otraVersion[0].ISRC)
	}

	// Un ítem que YA tiene ISRC no se pisa.
	yaTiene := []FeedItemGo{
		{Type: "track", Name: "One More Time", Artists: "Daft Punk", DurationMs: 320000, ISRC: "OTROISRC1234"},
		{Type: "track", Name: "One More Time", Artists: "Daft Punk", DurationMs: 320000, ISRC: "GBDUW0000059"},
	}
	propagarISRC(yaTiene)
	if yaTiene[0].ISRC != "OTROISRC1234" {
		t.Errorf("se pisó un ISRC existente: %q", yaTiene[0].ISRC)
	}
}

// TestElMismoTemaNoSeRepiteEntreExtensiones reproduce el síntoma de "Todas":
// el mismo tema llegando desde cuatro extensiones, cada una escribiéndolo a su
// manera. Antes entraban los cuatro; ahora entra uno —el que trae el ISRC— y
// los demás se completan con él.
func TestElMismoTemaNoSeRepiteEntreExtensiones(t *testing.T) {
	buffer := []FeedItemGo{}
	lotes := [][]FeedItemGo{
		{{Type: "track", Name: "One More Time", Artists: "Daft Punk", DurationMs: 320000, ISRC: "GBDUW0000059", Source: "deezer"}},
		{{Type: "track", Name: "One More Time (Remastered)", Artists: "Daft Punk, Pharrell Williams", DurationMs: 320100, Source: "ytmusic-spotiflac"}},
		{{Type: "track", Name: "one more time", Artists: "Daft Punk", DurationMs: 320000, Source: "soundcloud"}},
		{{Type: "album", Name: "Discovery", Artists: "Daft Punk", ID: "302127", Source: "deezer"}},
		{{Type: "album", Name: "Discovery", Artists: "Daft Punk", ID: "302127", Source: "deezer"}},
	}
	for _, lote := range lotes {
		for _, item := range lote {
			if esItemBusquedaDuplicado(buffer, item) {
				continue
			}
			buffer = append(buffer, item)
		}
		propagarISRC(buffer)
	}

	if len(buffer) != 2 {
		t.Fatalf("se esperaban 1 track + 1 álbum, hay %d: %+v", len(buffer), buffer)
	}
	if buffer[0].ISRC != "GBDUW0000059" {
		t.Errorf("el track conservado debe ser el que trae el ISRC: %q", buffer[0].ISRC)
	}
	if buffer[1].Type != "album" {
		t.Error("el álbum duplicado (mismo id) no se deduplicó")
	}
}
