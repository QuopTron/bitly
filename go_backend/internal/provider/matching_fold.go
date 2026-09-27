package provider

import (
	"strings"
	"unicode"
)

// FoldTrack lowercases and folds common accented characters for fair
// comparison, keeping letters/digits separated by single spaces.
// Combining marks (e.g. "n\u0303" instead of "ñ") are dropped so titles that
// differ only in NFD/NFC encoding still match ("Pun\u0303aladas" == "Puñaladas").

// replacerAcentos quita los acentos que rompen la comparación de títulos
// ("Puñaladas" == "Punaladas"). Compartido por FoldTrack y el normalizador de
// marcadores de versión.
var replacerAcentos = strings.NewReplacer(
	"á", "a", "à", "a", "ä", "a", "â", "a", "ã", "a", "å", "a",
	"é", "e", "è", "e", "ë", "e", "ê", "e",
	"í", "i", "ì", "i", "ï", "i", "î", "i",
	"ó", "o", "ò", "o", "ö", "o", "ô", "o", "õ", "o",
	"ú", "u", "ù", "u", "ü", "u", "û", "u",
	"ñ", "n", "ç", "c",
)

func FoldTrack(s string) string {
	s = replacerAcentos.Replace(strings.ToLower(s))
	var b strings.Builder
	prevSpace := true
	for _, r := range s {
		// Drop any remaining combining mark so NFC/NFD forms fold identically.
		if unicode.Is(unicode.Mn, r) {
			continue
		}
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
			prevSpace = false
		} else if !prevSpace {
			b.WriteByte(' ')
			prevSpace = true
		}
	}
	fields := strings.Fields(b.String())
	out := make([]string, 0, len(fields))
	for _, w := range fields {
		if !noiseWords[w] {
			out = append(out, w)
		}
	}
	return strings.Join(out, " ")
}

// IsNonOriginalTitle reports whether the raw title indicates a version that is
// not the original studio cut (remix/live/cover/acoustic/en vivo/...).
// Los marcadores de una palabra se comparan por palabra completa: "Alive" no
// es un "live", "Discover" no es un "cover".
func IsNonOriginalTitle(rawTitle string) bool {
	titulo := tituloParaMarcadores(rawTitle)
	palabras := palabrasDelTitulo(titulo)
	for _, m := range nonOriginalMarkers {
		if marcadorPresente(titulo, palabras, m) {
			return true
		}
	}
	return false
}

// IsNonOriginalVariant reports whether [rawTitle] is a NON-original version of
// [queryTitle]. Un marcador como "remix"/"live" solo senala una version
// diferente cuando la CONSULTA no lo contiene ya — "MORNING DEW (DONK) REMIX"
// es el titulo oficial de la cancion de Beyonce, asi que un candidato con el
// mismo "remix" es el original, no una variante.
func IsNonOriginalVariant(rawTitle, queryTitle string) bool {
	return marcadorNoOriginalFueraDeConsulta(rawTitle, queryTitle)
}

// marcadorNoOriginalFueraDeConsulta reporta si [texto] lleva un marcador de
// versión (remix/live/cover/piano/karaoke/...) que la [consulta] NO lleva. Es la
// regla por la que "MORNING DEW (DONK) REMIX" sigue siendo el original de
// Beyoncé: el marcador solo cuenta si el PEDIDO no lo trae ya.
func marcadorNoOriginalFueraDeConsulta(texto, consulta string) bool {
	titulo := tituloParaMarcadores(texto)
	if titulo == "" {
		return false
	}
	palabras := palabrasDelTitulo(titulo)
	cons := tituloParaMarcadores(consulta)
	palabrasConsulta := palabrasDelTitulo(cons)
	for _, m := range nonOriginalMarkers {
		if !marcadorPresente(titulo, palabras, m) {
			continue
		}
		// Solo es variante si el PEDIDO no trae el mismo marcador (mismo
		// criterio por palabra que arriba).
		if !marcadorPresente(cons, palabrasConsulta, m) {
			return true
		}
	}
	return false
}

// IsNonOriginalTrack reporta si el candidato [t] es una versión NO original por
// CUALQUIERA de sus campos —título, artista o álbum—, no solo por el título.
//
// Por qué importa: cada extensión pone el marcador donde su catálogo lo tiene.
// Un disco de covers se llama a sí mismo "Piano Covers" o firma como "Slowed
// Sounds"/"Epic Symphonic Orchestra", con un título pelado ("BbY WOW"). Mirando
// solo el título, esos covers pasaban como el original y su ISRC/audio (la
// versión de piano) se servía en vez de la grabación pedida. El álbum no tiene
// contraparte en la consulta, así que un marcador ahí siempre identifica una
// edición derivada ("Live at ...", "The Remixes").
func IsNonOriginalTrack(t TrackResult, queryTitle, queryArtist string) bool {
	if marcadorNoOriginalFueraDeConsulta(t.Title, queryTitle) {
		return true
	}
	if marcadorNoOriginalFueraDeConsulta(t.Artist, queryArtist) {
		return true
	}
	if strings.TrimSpace(t.Album) != "" && IsNonOriginalTitle(t.Album) {
		return true
	}
	return false
}

// tokenOverlap returns the fraction of shared tokens between two folded strings.
