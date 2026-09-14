package gobackend

import (
	"strings"
)

// ─────────────────────────────────────────────────────────────────────────
// IDENTIDAD DE UN TRACK ENTRE TODAS LAS EXTENSIONES
//
// Qué problema resuelve. El ISRC es el único identificador que TODAS las
// fuentes comparten para la misma grabación, y es la llave con la que se
// deduplica entre extensiones y se cruzan likes/descargas/librería local. Pero
// varias fuentes no lo publican en la BÚSQUEDA (YouTube, SoundCloud, Internet
// Archive, y también Deezer: su /search no lo trae, solo /track/{id}). Sin
// ISRC, el respaldo comparaba nombre y artista LITERALES, así que el mismo
// tema salía varias veces en "Todas" — "One More Time" no coincidía con
// "One More Time (Remastered)" ni "Daft Punk" con "Daft Punk, Pharrell".
//
// Se resuelve en dos pasos, en ese orden:
//
//  1. PROPAGAR el ISRC real cuando otra extensión lo trae para el mismo
//     track (nombre + artista normalizados y misma duración). No se inventa
//     nada: se toma prestado el ISRC que ya existe en la respuesta.
//  2. Si aun así no hay ISRC, el track se compara por CLAVE CANÓNICA
//     (nombre + artista principal + duración). Sirve para deduplicar, y
//     NUNCA se disfraza de ISRC — ver [claveCanonicaTrack].
// ─────────────────────────────────────────────────────────────────────────

// toleranciaDuracionMs es cuánta diferencia de duración se tolera para
// considerar que dos resultados son la MISMA grabación. Cubre el redondeo de
// cada API (unas dan ms exactos, otras segundos) sin fundir dos versiones
// distintas, que suelen diferenciarse por bastante más.
const toleranciaDuracionMs = 2500

// acentos mapea los diacríticos latinos que aparecen de verdad en los
// catálogos. Se hace a mano para no arrastrar una dependencia por esto.
var acentos = map[rune]rune{
	'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
	'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
	'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
	'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
	'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
	'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y',
}

// ruidoEntreParentesis son las coletillas que agregan las fuentes y que NO
// cambian la grabación: remaster, video oficial, letra, calidad. Se quitan
// para poder cruzar el mismo tema escrito distinto en cada catálogo.
var ruidoEntreParentesis = []string{
	"remaster", "remastered", "remasterizado", "remasterizada",
	"official", "oficial", "video", "audio", "lyric", "letra",
	"visualizer", "hd", "hq", "explicit", "deluxe", "bonus",
	"radio edit", "single version", "album version", "feat", "ft.",
	"with ", "con ",
}

// normalizarIdentidad deja un texto comparable entre catálogos: minúsculas,
// sin acentos, sin puntuación y con espacios simples.
func normalizarIdentidad(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(strings.TrimSpace(s)) {
		if mapped, ok := acentos[r]; ok {
			r = mapped
		}
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9':
			b.WriteRune(r)
		case r == ' ', r == '-', r == '_', r == '/', r == '\'':
			b.WriteRune(' ')
		}
	}
	return strings.Join(strings.Fields(b.String()), " ")
}

// esBloqueRuido dice si un bloque entre paréntesis/corchetes es una coletilla
// de publicación (remaster, video oficial, letra...) y no parte del título.
func esBloqueRuido(bloque string) bool {
	for _, marca := range ruidoEntreParentesis {
		if strings.Contains(bloque, marca) {
			return true
		}
	}
	return false
}

// quitarRuido saca los bloques entre paréntesis/corchetes que solo son
// coletillas de publicación, y la cola "- Remastered 2011" al final. Un bloque
// que NO es ruido se deja intacto (un "(Live)" del título no se toca).
func quitarRuido(s string) string {
	var b strings.Builder
	i := 0
	for i < len(s) {
		c := s[i]
		if c == '(' || c == '[' {
			cierre := byte(')')
			if c == '[' {
				cierre = ']'
			}
			if j := strings.IndexByte(s[i:], cierre); j >= 0 {
				bloque := strings.ToLower(s[i : i+j+1])
				nuevoI := i + j + 1
				if !esBloqueRuido(bloque) {
					b.WriteString(s[i:nuevoI])
				}
				i = nuevoI
				continue
			}
		}
		b.WriteByte(c)
		i++
	}
	out := b.String()

	// Cola del tipo "Tema - Remastered 2011" (sin paréntesis).
	if idx := strings.LastIndex(out, " - "); idx > 0 {
		cola := strings.ToLower(out[idx+3:])
		for _, marca := range []string{"remaster", "remasterizado", "radio edit"} {
			if strings.HasPrefix(cola, marca) {
				out = out[:idx]
				break
			}
		}
	}
	return strings.TrimSpace(out)
}

// artistaPrincipalDe toma el primer artista de la lista: entre fuentes, el
// secundario cambia (una lista features, otra no), el principal no.
func artistaPrincipalDe(artists string) string {
	cortado := artists
	for _, sep := range []string{",", "&", ";", " feat.", " feat ", " ft.", " ft ", " with ", " x "} {
		if i := strings.Index(strings.ToLower(cortado), sep); i > 0 {
			cortado = cortado[:i]
		}
	}
	return normalizarIdentidad(cortado)
}

// claveNombre es la parte de la identidad que no depende de la duración.
func claveNombre(name, artists string) string {
	return normalizarIdentidad(quitarRuido(name)) + "|" + artistaPrincipalDe(artists)
}

// claveCanonicaTrack arma la identidad de un track a partir de su nombre,
// artista y duración.
//
// POR QUÉ NO DEVUELVE UN ISRC "INVENTADO": un ISRC falso con forma de ISRC
// (doce caracteres, p. ej. "QZABC1234567") sería peligroso, no útil — la app
// lo manda a los catálogos para resolver la descarga (Deezer tiene
// /track/isrc:{isrc}). Un código inventado no da "no encontrado": da OTRA
// canción, o sea una descarga equivocada. Por eso la clave es explícitamente
// local (prefijo `synth:`) y solo se usa para comparar dentro de la app.
func claveCanonicaTrack(name, artists string, durationMs int) string {
	base := "synth:" + claveNombre(name, artists)
	if durationMs > 0 {
		// Redondeo a 2 s: absorbe el redondeo de las APIs sin mezclar dos
		// versiones distintas de la misma canción.
		return base + "|" + itoa(durationMs/2000)
	}
	return base
}

// esElMismoTrack decide si dos resultados de búsqueda son la misma grabación.
//
// Con ISRC en ambos lados manda el ISRC. Si falta en alguno, se comparan
// nombre+artista normalizados y, cuando las dos duraciones se conocen, se
// exige que coincidan: sin ese chequeo un radio edit y el tema original
// colapsarían en uno solo (y se perdería una de las dos versiones).
func esElMismoTrack(a, b FeedItemGo) bool {
	if a.ISRC != "" && b.ISRC != "" {
		return strings.EqualFold(strings.TrimSpace(a.ISRC), strings.TrimSpace(b.ISRC))
	}
	if claveNombre(a.Name, a.Artists) != claveNombre(b.Name, b.Artists) {
		return false
	}
	if a.DurationMs > 0 && b.DurationMs > 0 {
		dif := a.DurationMs - b.DurationMs
		if dif < 0 {
			dif = -dif
		}
		return dif <= toleranciaDuracionMs
	}
	return true
}

// propagarISRC completa el ISRC que le falta a un resultado usando el que otra
// extensión ya trajo para la MISMA grabación (nombre+artista normalizados y
// duración coincidente). Es best-effort: lo que no se puede confirmar con
// duración se deja sin ISRC, en vez de arriesgar una identidad equivocada.
func propagarISRC(items []FeedItemGo) {
	for i := range items {
		if items[i].Type != "track" || items[i].ISRC != "" {
			continue
		}
		for j := range items {
			if i == j || items[j].Type != "track" || items[j].ISRC == "" {
				continue
			}
			// Acá la duración es obligatoria en los dos: es el único
			// respaldo cuando no hay ISRC, y prestar un ISRC equivocado
			// contamina todo lo que depende de la identidad.
			if items[i].DurationMs <= 0 || items[j].DurationMs <= 0 {
				continue
			}
			if claveNombre(items[i].Name, items[i].Artists) !=
				claveNombre(items[j].Name, items[j].Artists) {
				continue
			}
			dif := items[i].DurationMs - items[j].DurationMs
			if dif < 0 {
				dif = -dif
			}
			if dif > toleranciaDuracionMs {
				continue
			}
			items[i].ISRC = items[j].ISRC
			break
		}
	}
}

// itoa evita importar strconv solo por esto.
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}
