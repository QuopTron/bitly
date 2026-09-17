// ─────────────────────────────────────────────────────────────
// sitios_flac_lectura.go — Lectura del HTML de un sitio raspable de
// FLAC (ver sitios_flac.go): convierte su página de búsqueda en una
// lista de candidatos con los datos que hacen falta para identificarlos
// y para pedirles la descarga.
//
// Por qué: estos sitios no tienen API JSON. Todo lo que ofrecen viaja
// dentro de formularios HTML, así que la lectura se hace con
// expresiones sobre el marcado y se fija con tests contra HTML real
// guardado (ver sitios_flac_test.go).
//
// Se conecta con: sitios_flac_analisis.go (el que elige) y
// sitios_flac_superflac.go (el que pide la descarga).
// Parte del flujo: rescate de FLAC por descarga (no streaming).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"html"
	"regexp"
	"strconv"
	"strings"
)

// candidatoSitio es una pista ofrecida por un sitio raspable.
type candidatoSitio struct {
	titulo    string
	artista   string
	album     string
	durMS     int
	musicURL  string // link del catálogo (open.qobuz.com/track/…, tidal.com/track/…)
	tipo      string // resource_kind que espera el formulario
	token     string // _token anti-CSRF del formulario
	calidades []string
}

var (
	reFormulario = regexp.MustCompile(`(?s)<form class="result-item result-track">(.*?)</form>`)
	reOculto     = regexp.MustCompile(`<input type="hidden" name="([^"]+)" value="([^"]*)"`)
	reNombre     = regexp.MustCompile(`class="result-item__name">([^<]*)<`)
	reSub        = regexp.MustCompile(`class="result-item__sub">([^<]*)<`)
	reOpcion     = regexp.MustCompile(`<option value="([^"]+)"`)
	reDuracion   = regexp.MustCompile(`(\d{1,2}):(\d{2})(?::(\d{2}))?`)
)

// leerCandidatos extrae las pistas de un HTML de búsqueda del sitio.
func leerCandidatos(htmlBusqueda string) []candidatoSitio {
	bloques := reFormulario.FindAllStringSubmatch(htmlBusqueda, -1)
	candidatos := make([]candidatoSitio, 0, len(bloques))
	for _, bloque := range bloques {
		c := candidatoSitio{calidades: valoresDeOpcion(bloque[1])}
		for _, oculto := range reOculto.FindAllStringSubmatch(bloque[1], -1) {
			switch oculto[1] {
			case "music_url":
				c.musicURL = html.UnescapeString(oculto[2])
			case "resource_kind":
				c.tipo = oculto[2]
			case "_token":
				c.token = oculto[2]
			}
		}
		if m := reNombre.FindStringSubmatch(bloque[1]); m != nil {
			c.titulo = strings.TrimSpace(html.UnescapeString(m[1]))
		}
		if m := reSub.FindStringSubmatch(bloque[1]); m != nil {
			c.artista, c.album, c.durMS = partirRenglon(html.UnescapeString(m[1]))
		}
		if c.musicURL != "" && c.token != "" {
			candidatos = append(candidatos, c)
		}
	}
	return candidatos
}

// valoresDeOpcion devuelve el VALUE de cada opción de calidad. Se toma el
// grupo capturado y no la coincidencia entera: `FindAllString` devolvería
// `<option value="FLAC">` y ninguna calidad coincidiría nunca.
func valoresDeOpcion(bloque string) []string {
	grupos := reOpcion.FindAllStringSubmatch(bloque, -1)
	valores := make([]string, 0, len(grupos))
	for _, g := range grupos {
		valores = append(valores, g[1])
	}
	return valores
}

// partirRenglon separa "Artista - Álbum - 3:03" en sus tres datos. El artista
// puede traer " - " propio hasta el álbum, así que el corte se hace por el
// FINAL: la duración siempre va última.
func partirRenglon(sub string) (artista, album string, durMS int) {
	sub = strings.TrimSpace(sub)
	if m := reDuracion.FindStringSubmatch(sub); m != nil {
		horas, _ := strconv.Atoi(m[3])
		minutos, _ := strconv.Atoi(m[1])
		segundos, _ := strconv.Atoi(m[2])
		durMS = ((horas*60+minutos)*60 + segundos) * 1000
		if i := strings.LastIndex(sub, m[0]); i > 0 {
			sub = strings.TrimRight(strings.TrimSpace(sub[:i]), "- ")
		}
	}
	partes := strings.Split(sub, " - ")
	if len(partes) >= 2 {
		return strings.TrimSpace(partes[0]), strings.TrimSpace(strings.Join(partes[1:], " - ")), durMS
	}
	return strings.TrimSpace(sub), "", durMS
}
