// ─────────────────────────────────────────────────────────────
// analisis.go — Análisis PURO del HTML de Last.fm (sin red ni estado):
// saca las pistas de una tabla y los géneros de una ficha.
//
// Se separó a propósito del cliente para poder probarlo con el HTML real
// del sitio, sin tocar la red.
// ─────────────────────────────────────────────────────────────

package lastfm

import (
	"html"
	"regexp"
	"strconv"
	"strings"
)

// Pista es una pista tal como la publica Last.fm: nombre canónico, artistas
// (invitados incluidos), duración y el video OFICIAL de YouTube de esa pista.
type Pista struct {
	Nombre     string
	Artistas   string
	DuracionMs int
	YouTubeID  string
}

var (
	// Cada fila de una tabla de pistas trae este atributo, sea la ficha de un
	// álbum, la lista completa de un artista o la página de resultados.
	reFilaPista = regexp.MustCompile(`data-scrobble-row`)
	reNombre    = regexp.MustCompile(`data-track-name="([^"]*)"`)
	reYouTube   = regexp.MustCompile(`data-youtube-id="([A-Za-z0-9_-]{11})"`)
	reDuracion  = regexp.MustCompile(`chartlist-duration"[^>]*>\s*([0-9]{1,2}:[0-9]{2})`)
	// El bloque de reproducción de CADA fila trae los créditos completos
	// (invitados incluidos), así que es la fuente más fiable del artista.
	reArtistas = regexp.MustCompile(`data-artist-name="([^"]*)"`)
	// Reserva para páginas sin bloque de reproducción.
	reArtistasAlt = regexp.MustCompile(`chartlist-artist"[\s\S]{0,200}?>\s*<a[^>]*>([^<]+)</a>`)
	reEtiqueta    = regexp.MustCompile(`href="/tag/([^"?/#]+)"`)
)

// pistasDeTabla parte el HTML por FILA y saca de cada una lo que necesita.
//
// El parseo es POR FILA, no "el próximo data-youtube-id que aparezca": el
// video va ANTES del nombre dentro de la fila, así que emparejar por proximidad
// global corría todo un lugar y le daba a cada pista el video de la siguiente.
func pistasDeTabla(cuerpo string) []Pista {
	trozos := reFilaPista.Split(cuerpo, -1)
	if len(trozos) < 2 {
		return nil
	}
	pistas := make([]Pista, 0, len(trozos)-1)
	for _, fila := range trozos[1:] {
		nombre := primerGrupo(reNombre, fila)
		if nombre == "" {
			continue
		}
		artistas := primerGrupo(reArtistas, fila)
		if artistas == "" {
			artistas = primerGrupo(reArtistasAlt, fila)
		}
		pistas = append(pistas, Pista{
			Nombre:     limpiarTexto(nombre),
			Artistas:   limpiarTexto(artistas),
			DuracionMs: duracionAMs(primerGrupo(reDuracion, fila)),
			YouTubeID:  primerGrupo(reYouTube, fila),
		})
	}
	return pistas
}

// generosDe saca las etiquetas de una ficha de artista (equivalen al género).
func generosDe(cuerpo string) []string {
	vistos := map[string]bool{}
	var generos []string
	for _, m := range reEtiqueta.FindAllStringSubmatch(cuerpo, -1) {
		g := limpiarTexto(strings.ReplaceAll(m[1], "+", " "))
		if g == "" || vistos[g] {
			continue
		}
		vistos[g] = true
		generos = append(generos, g)
		if len(generos) == 8 {
			break
		}
	}
	return generos
}

// duracionAMs convierte "3:02" (o "1:02:03") a milisegundos. 0 si no se puede.
func duracionAMs(texto string) int {
	texto = strings.TrimSpace(texto)
	if texto == "" {
		return 0
	}
	partes := strings.Split(texto, ":")
	total := 0
	for _, p := range partes {
		n, err := strconv.Atoi(strings.TrimSpace(p))
		if err != nil {
			return 0
		}
		total = total*60 + n
	}
	return total * 1000
}

// limpiarTexto desescapa entidades y colapsa espacios.
func limpiarTexto(s string) string {
	return strings.Join(strings.Fields(html.UnescapeString(s)), " ")
}

func primerGrupo(re *regexp.Regexp, s string) string {
	m := re.FindStringSubmatch(s)
	if len(m) < 2 {
		return ""
	}
	return m[1]
}

// claveComparacion deja un texto comparable entre fuentes: minúsculas, sin
// acentos, sin puntuación y con espacios simples. Es la misma idea que usa el
// resto del backend para saber si dos resultados son la MISMA grabación.
func claveComparacion(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(strings.TrimSpace(s)) {
		switch {
		case r == 'á' || r == 'à' || r == 'ä' || r == 'â' || r == 'ã':
			r = 'a'
		case r == 'é' || r == 'è' || r == 'ë' || r == 'ê':
			r = 'e'
		case r == 'í' || r == 'ì' || r == 'ï' || r == 'î':
			r = 'i'
		case r == 'ó' || r == 'ò' || r == 'ö' || r == 'ô' || r == 'õ':
			r = 'o'
		case r == 'ú' || r == 'ù' || r == 'ü' || r == 'û':
			r = 'u'
		case r == 'ñ':
			r = 'n'
		case r == 'ç':
			r = 'c'
		}
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
			continue
		}
		if r == ' ' || r == '-' || r == '_' || r == '/' || r == '\'' || r == '.' {
			b.WriteRune(' ')
		}
	}
	return strings.Join(strings.Fields(b.String()), " ")
}
