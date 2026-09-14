// nombre_compartido_test.go — el parseo de la ruta compartida es lo que decide
// si el ranking del repo ACEPTA un archivo de Soulseek o lo descarta por
// "artista ausente". Por eso se prueba con las formas reales que usa la red.
package soulseek

import (
	"testing"
)

func TestParseoDeRutaCompartida(t *testing.T) {
	casos := []struct {
		ruta    string
		artista string
		titulo  string
		porQue  string
	}{
		{
			ruta:    `Music\Daft Punk\Discovery\01 - One More Time.flac`,
			artista: "Daft Punk", titulo: "One More Time",
			porQue: "el caso típico: carpeta + número de pista + tema",
		},
		{
			ruta:    `Daft Punk - One More Time.mp3`,
			artista: "Daft Punk", titulo: "One More Time",
			porQue: "Artista - Tema en el nombre pelado",
		},
		{
			ruta:    `Daft Punk - Discovery - 01 - One More Time.flac`,
			artista: "Daft Punk", titulo: "One More Time",
			porQue: "Artista - Álbum - pista - tema: gana el último segmento",
		},
		{
			ruta:    `01 - Daft Punk - One More Time.flac`,
			artista: "Daft Punk", titulo: "One More Time",
			porQue: "pista AL PRINCIPIO: el primer guion no separa el artista",
		},
		{
			ruta:    `One_More_Time.flac`,
			artista: "", titulo: "One More Time",
			porQue: "guiones bajos son espacios y no hay artista: no se inventa",
		},
		{
			ruta:    `Music/[01] One More Time.flac`,
			artista: "", titulo: "One More Time",
			porQue: "número de pista entre corchetes, con separador POSIX",
		},
		{
			ruta:    `Guns N' Roses - Sweet Child O' Mine.flac`,
			artista: "Guns N' Roses", titulo: "Sweet Child O' Mine",
			porQue: "apóstrofes y espacios internos no deben romper el corte",
		},
		{
			ruta:    `Mr. Brightside.flac`,
			artista: "", titulo: "Mr. Brightside",
			porQue: "el punto de una abreviatura no es una extensión",
		},
		{
			ruta:    `24K Magic.flac`,
			artista: "", titulo: "24K Magic",
			porQue: "un título que empieza con dígitos no pierde el número",
		},
		{
			ruta:    `tema sin extension`,
			artista: "", titulo: "tema sin extension",
			porQue: "sin extensión no se corta nada",
		},
	}

	for _, c := range casos {
		artista, titulo := parsearNombreCompartido(c.ruta)
		if artista != c.artista || titulo != c.titulo {
			t.Errorf("%s\n  ruta: %q\n   got: (%q, %q)\n  want: (%q, %q)",
				c.porQue, c.ruta, artista, titulo, c.artista, c.titulo)
		}
	}
}

// La razón de ser del parseo: un archivo de Soulseek con la convención normal
// tiene que pasar el ranking del repo como ORIGINAL ESTRICTO (título fuerte +
// evidencia de artista). Sin esto, el FLAC que buscábamos se descartaba.
func TestElParseoHabilitaElMatchDelRanking(t *testing.T) {
	artista, titulo := parsearNombreCompartido(`Music\Daft Punk\Discovery\01 - One More Time.flac`)
	if artista == "" {
		t.Fatal("sin artista el candidato cae a la pasada best-effort en vez de ser original estricto")
	}
	if titulo == "" {
		t.Fatal("título vacío no puede matchear")
	}
	// El nombre de archivo crudo (con extensión y carpeta) NO sirve como
	// título: por eso se parsea antes de devolverlo al ranking.
	crudo := ArchivoEncontrado{Ruta: `Music\Daft Punk\Discovery\01 - One More Time.flac`}.NombreArchivo()
	if crudo == titulo {
		t.Fatalf("el título devuelto no debería ser el nombre crudo (%q)", crudo)
	}
}

func TestQuitarNumeroDePistaYSusLimites(t *testing.T) {
	casos := map[string]string{
		"01 - Tema": "Tema",
		"1. Tema":   "Tema",
		"1_Tema":    "Tema",
		"001 Tema":  "Tema",
		"[03] Tema": "Tema",
		"24K Magic": "24K Magic", // dígitos que son parte del título
		"1984":      "1984",      // un año no es una pista
		"1234 Tema": "1234 Tema", // más de 3 dígitos: no es número de pista
		"Tema":      "Tema",
	}
	for entrada, esperado := range casos {
		if got := quitarNumeroDePista(entrada); got != esperado {
			t.Errorf("quitarNumeroDePista(%q) = %q, se esperaba %q", entrada, got, esperado)
		}
	}
}
