package provider

import "testing"

// matching_cover_credito_test.go — guardas del caso "BbY WOW".
//
// En vivo (flacdownloader/Qobuz, Apple, iTunes) la búsqueda de "BbY WOW" de
// KAROL G, Judeline & rusowsky devuelve, además del corte real, discos de
// covers/tributo que acreditan al artista original en el título:
//
//	"BbY WOW (KAROL G, Judeline, rusowsky)" — Epic Symphonic Orchestra
//	"BbY Wow (Piano Version)"               — Christian Salerno
//	"BbY WOW - KAROL G, Judeline & rusowsky" — Slowed Sounds
//
// Con la comprobación vieja de "artista dentro del título" la orquesta pasaba
// como ORIGINAL y su ISRC (la versión de piano/orquesta) se elegía en lugar de
// USUG12607940: el toque desde el feed de Amazon sonaba la versión de versión.
// Estas pruebas fijan (1) que el crédito parentético no cuenta como el artista
// dentro del título, (2) que un artista de versión no alcanza con el crédito, y
// (3) que el re-subido legítimo (el artista junto al título) SÍ sigue contando.

func TestSinCreditosParenteticos(t *testing.T) {
	casos := map[string]string{
		"BbY WOW (KAROL G, Judeline, rusowsky)": "BbY WOW ",
		"Bby WOW (Instrumental) [KAROL G]":      "Bby WOW  ",
		"Shakira - DAI DAI":                     "Shakira - DAI DAI",
		"DAI DAI (Official Video) - Shakira":    "DAI DAI  - Shakira",
	}
	for in, want := range casos {
		if got := sinCreditosParenteticos(in); got != want {
			t.Errorf("sinCreditosParenteticos(%q) = %q, quería %q", in, got, want)
		}
	}
}

func TestArtistaEnTituloIgnoraCreditoParentetico(t *testing.T) {
	artista := "KAROL G, Judeline & rusowsky"
	if artistaEnTitulo(artista, "BbY WOW (KAROL G, Judeline, rusowsky)") {
		t.Error("el crédito parentético contó como el artista dentro del título")
	}
	if !artistaEnTitulo(artista, "KAROL G, Judeline & rusowsky - BbY WOW") {
		t.Error("el re-subido con el artista junto al título dejó de contar")
	}
}

func TestArtistaDeVersion(t *testing.T) {
	for _, a := range []string{"Epic Symphonic Orchestra", "Christian Salerno Piano", "Slowed Sounds", "Karaoke Live"} {
		if !artistaDeVersion(a) {
			t.Errorf("artistaDeVersion(%q) = false, quería true", a)
		}
	}
	for _, a := range []string{"minecraftdiablo", "Anna pham", "KAROL G"} {
		if artistaDeVersion(a) {
			t.Errorf("artistaDeVersion(%q) = true, quería false", a)
		}
	}
}

// TestDerivarISRCNoTomaCoverConCreditoParentetico es la guarda del bug: con el
// cover y el corte real en la MISMA lista, la derivación tiene que elegir el
// ISRC del corte real (o ninguno), nunca el de la versión.
func TestDerivarISRCNoTomaCoverConCreditoParentetico(t *testing.T) {
	var llamadas int
	r := registroConISRC("apple-music", []TrackResult{
		{ID: "cover", Title: "BbY WOW (KAROL G, Judeline, rusowsky)", Artist: "Epic Symphonic Orchestra", Duration: 238649, ISRC: "QTA2Q2602567"},
		{ID: "real", Title: "BbY WOW", Artist: "KAROL G, Judeline & rusowsky", Duration: 225835, ISRC: "USUG12607940"},
	}, &llamadas)

	got := DerivarISRC(r, "BbY WOW", "KAROL G, Judeline & rusowsky", 225000)
	if got != "USUG12607940" {
		t.Fatalf("DerivarISRC = %q, quería el ISRC del corte real USUG12607940", got)
	}
}

// TestDerivarISRCIgnoraCoverCuandoEsLoUnico: sin el corte real, un disco de
// covers no puede aportar identidad. Antes de esto, la orquesta pasaba como
// original y su ISRC se usaba para resolver el audio (la versión de piano).
func TestDerivarISRCIgnoraCoverCuandoEsLoUnico(t *testing.T) {
	var llamadas int
	r := registroConISRC("apple-music", []TrackResult{
		{ID: "cover", Title: "BbY WOW (KAROL G, Judeline, rusowsky)", Artist: "Epic Symphonic Orchestra", Duration: 238649, ISRC: "QTA2Q2602567"},
	}, &llamadas)

	// Título distinto para no chocar con la caché de la prueba anterior.
	if got := DerivarISRC(r, "Otra Cancion Cover", "KAROL G, Judeline & rusowsky", 238000); got != "" {
		t.Fatalf("DerivarISRC = %q, no debía derivar del cover", got)
	}
}

// TestDerivarISRCAceptaResubidoLegitimo: el caso que la evidencia por título
// existe para cubrir — SoundCloud/YouTube con el artista real dentro del título
// y el canal en el campo Artist — tiene que seguir funcionando.
func TestDerivarISRCAceptaResubidoLegitimo(t *testing.T) {
	var llamadas int
	r := registroConISRC("musicbrainz", []TrackResult{
		{ID: "sub", Title: "KAROL G, Judeline & rusowsky - BbY WOW", Artist: "minecraftdiablo", Duration: 225000, ISRC: "USUG12607940"},
	}, &llamadas)

	got := DerivarISRC(r, "BbY WOW", "KAROL G, Judeline & rusowsky", 225000)
	if got != "USUG12607940" {
		t.Fatalf("DerivarISRC = %q, quería el ISRC del re-subido verificado", got)
	}
}
