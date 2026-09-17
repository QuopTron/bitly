package flacrescue

// sitios_flac_test.go — Fija el contrato de los sitios raspables de FLAC.
//
// El HTML de abajo es RECORTE REAL de la página de búsqueda de superflac
// (mismos atributos y mismo renglón "Artista - Álbum - 3:03"), incluido el
// caso que obliga a verificar: buscar un ISRC inexistente devuelve decenas
// de pistas de otros artistas, y elegir la primera bajaría la canción
// equivocada y borraría el archivo bueno del usuario.
//
// Se ejecuta contra un servidor de prueba (httptest) que responde el mismo
// flujo que el sitio: búsqueda → job → enlace firmado. Nunca sale a la red.

import "testing"

func TestLeerCandidatosSacaTokenLinkYDuracion(t *testing.T) {
	candidatos := leerCandidatos(htmlBusqueda)
	if len(candidatos) != 3 {
		t.Fatalf("esperaba 3 candidatos, hubo %d", len(candidatos))
	}
	c := candidatos[0]
	if c.token != "tok-nuevayol" || c.musicURL != "https://open.qobuz.com/track/312055179" {
		t.Fatalf("token/link mal leídos: %+v", c)
	}
	if c.titulo != "NUEVAYoL" || c.tipo != "track" {
		t.Fatalf("título/tipo mal leídos: %+v", c)
	}
	// "Bad Bunny - DeBÍ TiRAR MáS FOToS - 3:03": el artista y el álbum van
	// separados por el MISMO " - " que el resto, así que el corte es por el final.
	if c.artista != "Bad Bunny" || c.album != "DeBÍ TiRAR MáS FOToS" {
		t.Fatalf("renglón mal partido: artista=%q album=%q", c.artista, c.album)
	}
	if c.durMS != 183000 {
		t.Fatalf("duración mal leída: %d", c.durMS)
	}
	if calidadPedida(c.calidades, "FLAC") != "FLAC" {
		t.Fatalf("debería pedir FLAC: %v", c.calidades)
	}
}

func TestPartirRenglonConArtistaYAlbumPegados(t *testing.T) {
	// Varios artistas y álbum con guiones: el corte sigue siendo el final.
	artista, album, dur := partirRenglon("rayder / GOLDEN / 1uno3tres - Ni Cabida Con Esto - 3:47")
	if artista != "rayder / GOLDEN / 1uno3tres" || album != "Ni Cabida Con Esto" || dur != 227000 {
		t.Fatalf("mal partido: %q | %q | %d", artista, album, dur)
	}
	// Sin duración en el renglón no se inventa una.
	if _, _, d := partirRenglon("Alguien - Disco"); d != 0 {
		t.Fatalf("no debería haber duración: %d", d)
	}
}

func TestElegirCandidatoRechazaLaBusquedaAproximada(t *testing.T) {
	candidatos := leerCandidatos(htmlBusqueda)
	// La canción pedida existe: gana el primer resultado.
	elegido, err := elegirCandidato(candidatos, "NUEVAYoL", "Bad Bunny", 183000, true)
	if err != nil {
		t.Fatalf("debería haber encontrado su canción: %v", err)
	}
	if elegido.musicURL != "https://open.qobuz.com/track/312055179" {
		t.Fatalf("eligió otro resultado: %s", elegido.musicURL)
	}

	// Otra canción: el sitio devolvió pistas con títulos PARECIDOS y ninguna es
	// la pedida. Debe rechazarlas todas en vez de bajar la primera.
	if _, err := elegirCandidato(candidatos, "Otra Cosa", "Otro Artista", 0, true); err == nil {
		t.Fatal("no debería aceptar un resultado que no coincide: bajaría la canción equivocada")
	}

	// Mismo título y artista pero OTRA duración: es una versión distinta.
	if _, err := elegirCandidato(candidatos, "NUEVAYoL", "Bad Bunny", 300000, true); err == nil {
		t.Fatal("no debería aceptar una duración que no coincide (otra grabación)")
	}
}

func TestElegirCandidatoSoloSinPerdidaCuandoSePideFLAC(t *testing.T) {
	candidatos := leerCandidatos(htmlBusqueda)
	// Cut To The Feeling viene de YouTube y solo tiene MP3_320: en un pedido
	// sin pérdida no puede ganar, aunque sea la única coincidencia.
	if _, err := elegirCandidato(candidatos, "Cut To The Feeling", "Carly Rae Jepsen", 208000, true); err == nil {
		t.Fatal("un resultado que solo ofrece MP3 no puede servir un pedido de FLAC")
	}
	// Sin pérdida no pedido: sí se puede usar (y pediría MP3_320).
	elegido, err := elegirCandidato(candidatos, "Cut To The Feeling", "Carly Rae Jepsen", 208000, false)
	if err != nil {
		t.Fatalf("debería aceptarlo para un pedido con pérdida: %v", err)
	}
	if calidadPedida(elegido.calidades, "MP3_320") != "MP3_320" {
		t.Fatal("debería pedir la única calidad que ofrece")
	}
}

func TestCalidadPedidaRespetaLoQueOfreceElFormulario(t *testing.T) {
	soloMP3 := []string{"MP3_320", "MP3_128"}
	if got := calidadPedida(soloMP3, "FLAC"); got != "MP3_320" {
		t.Fatalf("sin FLAC debería caer a 320: %q", got)
	}
	if got := calidadPedida([]string{"FLAC", "MP3_320"}, "FLAC"); got != "FLAC" {
		t.Fatalf("debería preferir FLAC: %q", got)
	}
	if got := calidadPedida(nil, "FLAC"); got != "" {
		t.Fatalf("sin calidades no hay nada que pedir: %q", got)
	}
}
