package provider

import "strings"

var noiseWords = map[string]bool{
	"official": true, "video": true, "audio": true, "lyrics": true, "lyric": true,
	"hd": true, "4k": true, "remaster": true, "remastered": true, "version": true,
	"feat": true, "featuring": true, "ft": true, "with": true, "album": true,
	"single": true, "ep": true,
}

// nonOriginalMarkers marcan una versión que NO es el corte original de estudio.
//
// Se comparan CONTRA EL TÍTULO NORMALIZADO DE MARCADORES (minúsculas, sin
// acentos, con todo el texto — ver tituloParaMarcadores), no contra el título
// plegado con FoldTrack: FoldTrack quita las palabras de ruido, y "version" es
// una de ellas, así que el marcador nunca se encontraría.
//
// Los de UNA palabra se comparan por PALABRA COMPLETA, no por substring: con
// substring, "live" marcaba también "Alive"/"Deliver" y "cover" marcaba
// "Discover"/"Recover" — una canción original con esas palabras en el título
// quedaba descartada como si fuera un cover en vivo. Los de VARIAS palabras
// (p. ej. "en vivo") se buscan como subcadena con espacios normalizados.
var nonOriginalMarkers = []string{
	// Inglés (base histórica)
	"remix", "live", "cover", "acoustic", "karaoke", "instrumental",
	"sped up", "spedup", "slowed", "acapella", "orchestral", "tribute",
	"orchestra", "piano", "string quartet", "choir",
	"extended", "rework", "remake", "nightcore", "dance edit", "radio edit",
	"club mix", "dub mix", "disco edit", "reprise",
	// Español / portugués: el repertorio que más se descarga en LATAM. Sin
	// estas, "(En Vivo)" o "(Acústico)" con el MISMO título y artista pasaban
	// como originales y se descargaba el directo o la versión acústica.
	"en vivo", "ao vivo", "en directo", "en directo desde", "en concierto",
	"acustico", "acustica", "version", "vivo desde",
	// Ediciones y remezclas modernas que hoy llegan por YouTube/TikTok.
	// "edit" va por palabra y así no toca "Edited"/"Edition"… que también son
	// ediciones; si el pedido las nombra, siguen aceptándose (ver
	// IsNonOriginalVariant: el marcador solo cuenta si la CONSULTA no lo trae).
	"edit", "flip", "bootleg", "mashup", "refix", "vip",
	// Efectos y derivados de re-subida (sped up/slowed ya están arriba).
	"reverb", "8d audio", "bass boosted", "phonk", "demo", "alternate",
}

// tituloParaMarcadores normaliza un título para buscar marcadores de versión:
// minúsculas, sin acentos y con los separadores convertidos en espacios, pero
// SIN quitar palabras (a diferencia de FoldTrack). Se usa para que
// "Acústico"/"ACUSTICO"/"acustico" sean el mismo marcador y para poder comparar
// por palabra completa.
func tituloParaMarcadores(s string) string {
	s = strings.ToLower(s)
	s = replacerAcentos.Replace(s)
	var b strings.Builder
	prevSpace := true
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9':
			b.WriteRune(r)
			prevSpace = false
		case r == ' ':
			if !prevSpace {
				b.WriteByte(' ')
				prevSpace = true
			}
		default:
			// Cualquier otro carácter (paréntesis, guion, punto, emoji) separa.
			if !prevSpace {
				b.WriteByte(' ')
				prevSpace = true
			}
		}
	}
	return strings.TrimSpace(b.String())
}

// marcadorPresente reporta si el marcador [m] está en [titulo] (ya pasado por
// tituloParaMarcadores) y [palabras] (sus tokens).
func marcadorPresente(titulo string, palabras map[string]bool, m string) bool {
	if strings.Contains(m, " ") {
		return strings.Contains(titulo, m)
	}
	return palabras[m]
}

// palabrasDelTitulo devuelve el conjunto de tokens de [titulo].
func palabrasDelTitulo(titulo string) map[string]bool {
	out := map[string]bool{}
	for _, w := range strings.Fields(titulo) {
		out[w] = true
	}
	return out
}
