package utils

import (
	"strings"
	"unicode"

	"golang.org/x/text/unicode/norm"
)

func writeNormalizedArtistRune(b *strings.Builder, r rune) {
	switch r {
	case 'đ':
		b.WriteString("dj")
	case 'ß':
		b.WriteString("ss")
	case 'æ':
		b.WriteString("ae")
	case 'œ':
		b.WriteString("oe")
	default:
		b.WriteRune(r)
	}
}

func NormalizeLooseTitle(title string) string {
	trimmed := strings.TrimSpace(strings.ToLower(title))
	if trimmed == "" {
		return ""
	}

	var b strings.Builder
	b.Grow(len(trimmed))

	for _, r := range trimmed {
		switch {
		case unicode.IsLetter(r), unicode.IsNumber(r):
			b.WriteRune(r)
		case unicode.IsSpace(r):
			b.WriteByte(' ')
		case r == '/', r == '\\', r == '_', r == '-', r == '|', r == '.', r == '&', r == '+':
			b.WriteByte(' ')
		}
	}

	return strings.Join(strings.Fields(b.String()), " ")
}

func NormalizeLooseArtistName(name string) string {
	trimmed := strings.TrimSpace(strings.ToLower(name))
	if trimmed == "" {
		return ""
	}

	decomposed := norm.NFD.String(trimmed)

	var b strings.Builder
	b.Grow(len(decomposed))

	for _, r := range decomposed {
		switch {
		case unicode.Is(unicode.Mn, r), unicode.Is(unicode.Mc, r), unicode.Is(unicode.Me, r):
			continue
		case unicode.IsLetter(r), unicode.IsNumber(r):
			writeNormalizedArtistRune(&b, r)
		case unicode.IsSpace(r):
			b.WriteByte(' ')
		case r == '/', r == '\\', r == '_', r == '-', r == '|', r == '.', r == '&', r == '+':
			b.WriteByte(' ')
		}
	}

	return strings.Join(strings.Fields(b.String()), " ")
}

func normalizeSymbolOnlyTitle(title string) string {
	trimmed := strings.TrimSpace(strings.ToLower(title))
	if trimmed == "" {
		return ""
	}

	var b strings.Builder
	b.Grow(len(trimmed))

	for _, r := range trimmed {
		switch {
		case unicode.IsLetter(r), unicode.IsNumber(r), unicode.IsSpace(r), unicode.IsPunct(r):
			continue
		// Drop combining marks such as emoji variation selectors.
		case unicode.Is(unicode.Mn, r), unicode.Is(unicode.Mc, r), unicode.Is(unicode.Me, r):
			continue
		default:
			b.WriteRune(r)
		}
	}

	return b.String()
}

func ArtistsMatch(expectedArtist, foundArtist string) bool {
	normExpected := NormalizeLooseArtistName(expectedArtist)
	normFound := NormalizeLooseArtistName(foundArtist)

	if normExpected == normFound {
		return true
	}

	if strings.Contains(normExpected, normFound) || strings.Contains(normFound, normExpected) {
		return true
	}

	expectedArtists := splitArtists(normExpected)
	foundArtists := splitArtists(normFound)

	for _, expected := range expectedArtists {
		for _, found := range foundArtists {
			if expected == found {
				return true
			}
			if strings.Contains(expected, found) || strings.Contains(found, expected) {
				return true
			}
			if sameWordsUnordered(expected, found) {
				return true
			}
		}
	}

	return isLatinScript(expectedArtist) != isLatinScript(foundArtist)
}
