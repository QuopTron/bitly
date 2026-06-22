package utils

import (
	"strings"
	"unicode"
)

func PrimaryArtistName(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	separators := []string{",", ";", "/", " • ", " & ", " feat. ", " ft. "}
	for _, sep := range separators {
		if parts := strings.SplitN(raw, sep, 2); len(parts) > 1 {
			return strings.TrimSpace(parts[0])
		}
	}
	return raw
}

func SplitArtistNamesJSON(rawArtists string) string {
	parts := splitArtists(rawArtists)
	result := "["
	for i, p := range parts {
		if i > 0 {
			result += ","
		}
		result += "\"" + p + "\""
	}
	result += "]"
	return result
}

func splitArtists(artists string) []string {
	normalized := artists
	normalized = strings.ReplaceAll(normalized, " feat. ", "|")
	normalized = strings.ReplaceAll(normalized, " feat ", "|")
	normalized = strings.ReplaceAll(normalized, " ft. ", "|")
	normalized = strings.ReplaceAll(normalized, " ft ", "|")
	normalized = strings.ReplaceAll(normalized, " & ", "|")
	normalized = strings.ReplaceAll(normalized, " and ", "|")
	normalized = strings.ReplaceAll(normalized, ", ", "|")
	normalized = strings.ReplaceAll(normalized, " x ", "|")
	normalized = strings.ReplaceAll(normalized, " y ", "|")
	normalized = strings.ReplaceAll(normalized, " vs ", "|")
	normalized = strings.ReplaceAll(normalized, " presents ", "|")

	parts := strings.Split(normalized, "|")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

func hasAlphaNumericRunes(value string) bool {
	for _, r := range value {
		if unicode.IsLetter(r) || unicode.IsNumber(r) {
			return true
		}
	}
	return false
}

func sameWordsUnordered(a, b string) bool {
	wordsA := strings.Fields(a)
	wordsB := strings.Fields(b)
	if len(wordsA) != len(wordsB) || len(wordsA) == 0 {
		return false
	}

	sortedA := make([]string, len(wordsA))
	sortedB := make([]string, len(wordsB))
	copy(sortedA, wordsA)
	copy(sortedB, wordsB)

	for i := 0; i < len(sortedA)-1; i++ {
		for j := i + 1; j < len(sortedA); j++ {
			if sortedA[i] > sortedA[j] {
				sortedA[i], sortedA[j] = sortedA[j], sortedA[i]
			}
			if sortedB[i] > sortedB[j] {
				sortedB[i], sortedB[j] = sortedB[j], sortedB[i]
			}
		}
	}

	for i := range sortedA {
		if sortedA[i] != sortedB[i] {
			return false
		}
	}
	return true
}

func isLatinScript(value string) bool {
	for _, r := range value {
		if r < 128 {
			continue
		}
		if (r >= 0x0100 && r <= 0x024F) ||
			(r >= 0x1E00 && r <= 0x1EFF) ||
			(r >= 0x00C0 && r <= 0x00FF) {
			continue
		}
		return false
	}
	return true
}
