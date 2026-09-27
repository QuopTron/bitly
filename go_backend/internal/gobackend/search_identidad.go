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
// Se resuelve en tres pasos, en ese orden:
//
//  1. FUSIONAR: cuando el mismo track llega desde otra fuente CON ISRC, el
//     item se descarta como duplicado pero su ISRC se queda en el que ya
//     estaba guardado (ver [fusionarISRC]). Es el camino principal, y el que
//     de verdad hacía falta: YouTube y SoundCloud no publican ISRC en la
//     búsqueda, así que su versión suele llegar primero y la fuente que sí lo
//     trae (Deezer, Tidal) llegaba después… y se tiraba con su ISRC adentro.
//  2. PROPAGAR el ISRC real entre los items que ya entraron, cuando otra
//     extensión lo trae para el mismo track (nombre + artista normalizados y
//     misma duración). No se inventa nada: se toma prestado el ISRC que ya
//     existe en la respuesta.
//  3. Si aun así no hay ISRC, el track se compara por CLAVE CANÓNICA
//     (nombre + artista principal + duración). Sirve para deduplicar, y NUNCA
//     se disfraza de ISRC.
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

// fusionarISRC pasa el ISRC del item DESCARTADO al que ya estaba en el buffer,
// cuando el guardado no traía ninguno. Devuelve true si lo completó.
//
// Sin esto el ISRC se perdía justo cuando más hace falta: la versión sin ISRC
// (YouTube, SoundCloud) suele llegar primero, y cuando después llega la que sí
// lo trae, el dedup la descarta como duplicado — y con ella se iba el ISRC, la
// llave con la que después se cruzan likes, descargas y biblioteca local entre
// extensiones. El item descartado ya no aporta nada más (se guarda el primero
// que llegó), así que lo único que hay que rescatar es su identidad.
//
// No se pisa un ISRC existente: si el que quedó ya tiene uno, el par no era un
// duplicado (esElMismoTrack resuelve por ISRC cuando están los dos) o el que
// llegó no aporta nada nuevo.
//
// Solo tracks: un álbum o una playlist pueden traer el campo `isrc` de la
// canción que los originó, pero la identidad de un álbum es su id, no el ISRC
// de una de sus pistas. Dejarlo pasar contaminaría el dedup de colecciones.
func fusionarISRC(buffer []FeedItemGo, pos int, item FeedItemGo) bool {
	if item.Type != "track" || item.ISRC == "" {
		return false
	}
	if pos < 0 || pos >= len(buffer) {
		return false
	}
	if buffer[pos].Type != "track" || buffer[pos].ISRC != "" {
		return false
	}
	buffer[pos].ISRC = item.ISRC
	return true
}

// propagarISRC completa el ISRC que le falta a un resultado usando el que otra
// extensión ya trajo para la MISMA grabación (nombre+artista normalizados y
// duración coincidente). Es best-effort: lo que no se puede confirmar con
// duración se deja sin ISRC, en vez de arriesgar una identidad equivocada.
//
// Devuelve true si completó al menos un ISRC, para que el llamador sepa si el
// contenido cambió y hay que invalidar la respuesta serializada.
func propagarISRC(items []FeedItemGo) bool {
	return propagarISRCCon(items, nil)
}

// propagarISRCCon es propagarISRC con la opción de recibir YA ARMADO el índice
// de claves canónicas (clave → posiciones de los tracks), que es exactamente lo
// que anexarSearchStream acaba de calcular para deduplicar el lote. Pasarlo
// evita normalizar dos veces la misma lista; nil = se arma acá.
//
// El índice que llega tiene que cubrir todos los tracks de `items` (el del
// dedup lo hace: se arma con el buffer completo y cada track que entra después
// se anota al agregarse).
func propagarISRCCon(items []FeedItemGo, grupos map[string][]int) bool {
	if len(items) < 2 {
		return false
	}
	// Primer filtro barato: lo que puede prestarse (track con ISRC y duración)
	// y lo que puede recibirlo. Sin las dos cosas no hay nada que hacer, y así
	// el caso común (lote ya completo, o lote sin ningún ISRC) se resuelve sin
	// armar el índice ni normalizar un solo texto.
	sinISRC, conISRC := 0, 0
	for i := range items {
		if items[i].Type != "track" || items[i].DurationMs <= 0 {
			continue
		}
		if items[i].ISRC == "" {
			sinISRC++
		} else {
			conISRC++
		}
	}
	if sinISRC == 0 || conISRC == 0 {
		return false
	}
	// Se agrupa por clave canónica (nombre+artista normalizados). Dos items de
	// grupos distintos NUNCA pueden ser la misma grabación, así que el barrido
	// interno queda dentro del grupo en vez de sobre toda la lista: la clave se
	// calcula UNA vez por item y no dos por cada par (que era el término O(n²)
	// más caro de todo el append).
	if grupos == nil {
		grupos = make(map[string][]int, len(items))
		for i := range items {
			if items[i].Type != "track" {
				continue
			}
			clave := claveNombre(items[i].Name, items[i].Artists)
			grupos[clave] = append(grupos[clave], i)
		}
	}
	rellenados := false
	for _, indices := range grupos {
		if len(indices) < 2 {
			continue
		}
		// `indices` va en orden de posición (se armó recorriendo la lista), así
		// que el primer candidato que encaja es el mismo que elegía el doble
		// barrido. Los ISRC que se van completando se escriben sobre `items`, y
		// el barrido vuelve a pasar por los mismos grupos: un item posterior
		// puede tomar prestado lo que se completó antes, igual que antes.
		for _, i := range indices {
			if items[i].ISRC != "" || items[i].DurationMs <= 0 {
				continue
			}
			for _, j := range indices {
				if j == i || items[j].ISRC == "" || items[j].DurationMs <= 0 {
					continue
				}
				// Acá la duración es obligatoria en los dos: es el único respaldo
				// cuando no hay ISRC, y prestar un ISRC equivocado contamina todo
				// lo que depende de la identidad.
				dif := items[i].DurationMs - items[j].DurationMs
				if dif < 0 {
					dif = -dif
				}
				if dif > toleranciaDuracionMs {
					continue
				}
				items[i].ISRC = items[j].ISRC
				rellenados = true
				break
			}
		}
	}
	return rellenados
}
