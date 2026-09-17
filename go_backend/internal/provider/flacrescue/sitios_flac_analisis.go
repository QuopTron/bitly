// ─────────────────────────────────────────────────────────────
// sitios_flac_analisis.go — Decisión del match para un sitio raspable de
// FLAC (ver sitios_flac.go): cuál de los candidatos leídos es la canción
// pedida y en qué calidad hay que pedirla.
//
// Por qué la verificación es obligatoria: estos sitios buscan por TEXTO
// aunque se les pase un ISRC. Con un ISRC que no existe en ningún
// catálogo devuelven decenas de resultados aproximados (probado:
// "ZZZZZZZZZZZZ" → 56 pistas de otros artistas). Sin el filtro se
// descargaría la canción equivocada con toda naturalidad, y encima
// reemplazaría el archivo bueno que el usuario ya tenía.
//
// El match se confirma con el trío título + artista + duración, el mismo
// criterio que usa el resto del backend (provider.FieldScore y la
// tolerancia de 4 s con la que se valida el FLAC ya bajado).
//
// Se conecta con: sitios_flac_lectura.go (candidatos) y
// sitios_flac_superflac.go (protocolo del sitio).
// Parte del flujo: rescate de FLAC por descarga (no streaming).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// toleranciaDurSitioMS es cuánto puede diferir la duración del sitio de la del
// catálogo. El mismo valor que usa la validación del FLAC ya bajado (4 s).
const toleranciaDurSitioMS = 4000

// puntajeFuerte es el mínimo que devuelve provider.FieldScore para considerar
// que un campo coincide DE VERDAD (3 = igual, 2 = uno contiene al otro o
// comparten el 85% de las palabras). Con 1 ("parecido") ya no alcanza.
const puntajeFuerte = 2

// elegirCandidato devuelve la pista que coincide con [titulo]/[artista] y (si
// se conoce) con [durMS]. Sin coincidencia verificable devuelve error: es
// preferible no bajar nada antes que bajar otra canción.
func elegirCandidato(candidatos []candidatoSitio, titulo, artista string, durMS int, sinPerdida bool) (candidatoSitio, error) {
	var elegido candidatoSitio
	mejor := -1.0
	for _, c := range candidatos {
		if sinPerdida && !ofreceSinPerdida(c.calidades) {
			continue
		}
		puntajeTitulo := provider.FieldScore(titulo, c.titulo)
		puntajeArtista := provider.FieldScore(artista, c.artista)
		if puntajeTitulo < puntajeFuerte || puntajeArtista < puntajeFuerte {
			continue
		}
		// Un título y artista iguales pero de OTRA duración son una versión
		// distinta (directo, remix, edit), y la duración es el único dato que
		// las separa. Si alguno de los dos no la trae, no se descarta.
		if durMS > 0 && c.durMS > 0 && absMS(c.durMS-durMS) > toleranciaDurSitioMS {
			continue
		}
		if puntaje := puntajeTitulo + puntajeArtista; puntaje > mejor {
			mejor, elegido = puntaje, c
		}
	}
	if mejor < 0 {
		return candidatoSitio{}, errSinCoincidencia
	}
	return elegido, nil
}

// absMS es el valor absoluto de una diferencia en milisegundos.
func absMS(v int) int {
	if v < 0 {
		return -v
	}
	return v
}

// ofreceSinPerdida reporta si el candidato tiene alguna calidad sin pérdida.
func ofreceSinPerdida(calidades []string) bool {
	for _, c := range calidades {
		if strings.HasPrefix(strings.ToUpper(strings.TrimSpace(c)), "FLAC") {
			return true
		}
	}
	return false
}

// calidadPedida mapea el formato del backend a una calidad del sitio,
// prefiriendo sin pérdida y respetando lo que el propio formulario ofrece:
// pedir una calidad ausente hace fallar el trabajo, y cada resultado solo
// lista las que tiene.
func calidadPedida(calidades []string, formato string) string {
	deseadas := []string{"FLAC", "MP3_320", "MP3_128"}
	switch normalizarFormato(formato) {
	case "MP3_128":
		deseadas = []string{"MP3_128", "MP3_320", "FLAC"}
	case "MP3_320":
		deseadas = []string{"MP3_320", "MP3_128", "FLAC"}
	}
	ofrecidas := map[string]bool{}
	for _, c := range calidades {
		ofrecidas[strings.ToUpper(strings.TrimSpace(c))] = true
	}
	for _, d := range deseadas {
		if ofrecidas[d] {
			return d
		}
	}
	return ""
}
