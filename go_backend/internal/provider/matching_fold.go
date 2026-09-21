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
	titulo := tituloParaMarcadores(rawTitle)
	palabras := palabrasDelTitulo(titulo)
	consulta := tituloParaMarcadores(queryTitle)
	palabrasConsulta := palabrasDelTitulo(consulta)
	for _, m := range nonOriginalMarkers {
		if !marcadorPresente(titulo, palabras, m) {
			continue
		}
		// Solo es variante si el PEDIDO no trae el mismo marcador (mismo
		// criterio por palabra que arriba).
		if !marcadorPresente(consulta, palabrasConsulta, m) {
			return true
		}
	}
	return false
}

// tokenOverlap returns the fraction of shared tokens between two folded strings.
