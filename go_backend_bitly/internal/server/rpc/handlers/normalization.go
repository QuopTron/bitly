package handlers

import (
	"strings"
	"unicode"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

// RegisterNormalizationHandlers registers text normalization RPC methods.
func RegisterNormalizationHandlers(reg *rpc.Registry) {
	reg.Register("normalizeForMatch", func(params map[string]interface{}) (interface{}, error) {
		text := rpc.Sp(params, "text")
		if text == "" {
			return "", nil
		}
		return normalizeLooseTitle(cleanTitle(text)), nil
	})

	reg.Register("normalizeSource", func(params map[string]interface{}) (interface{}, error) {
		source := rpc.Sp(params, "source")
		if source == "" {
			return "builtin", nil
		}
		s := strings.TrimSpace(strings.ToLower(source))
		switch s {
		case "qobuz_kennyy", "qobuz-web", "qobuz":
			return "qobuz", nil
		case "spotify-web", "spotify:track", "spotify":
			return "spotify", nil
		case "tidal-web", "tidal":
			return "tidal", nil
		case "deezer":
			return "deezer", nil
		case "apple-music", "apple_music":
			return "apple-music", nil
		case "soundcloud":
			return "soundcloud", nil
		case "ytmusic-Bitly", "ytmusic":
			return "ytmusic", nil
		case "pandora":
			return "pandora", nil
		case "amazon", "amazon_music":
			return "amazon", nil
		case "local":
			return "local", nil
		default:
			return s, nil
		}
	})

	reg.Register("primaryArtistName", func(params map[string]interface{}) (interface{}, error) {
		raw := rpc.Sp(params, "raw_artists")
		if raw == "" {
			return "", nil
		}
		// Get the first artist before any separator
		parts := splitArtists(raw)
		if len(parts) > 0 {
			return parts[0], nil
		}
		return raw, nil
	})

	reg.Register("splitArtistNames", func(params map[string]interface{}) (interface{}, error) {
		raw := rpc.Sp(params, "raw_artists")
		parts := splitArtists(raw)
		result := "["
		for i, p := range parts {
			if i > 0 {
				result += ","
			}
			result += "\"" + p + "\""
		}
		result += "]"
		return result, nil
	})
}

// splitArtists splits artist names by common separators.
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

// normalizeLooseTitle performs loose title normalization (lowercase, collapse separators).
func normalizeLooseTitle(title string) string {
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
		case r == '/' || r == '\\' || r == '_' || r == '-' || r == '|' || r == '.' || r == '&' || r == '+':
			b.WriteByte(' ')
		}
	}
	return strings.Join(strings.Fields(b.String()), " ")
}

// cleanTitle removes version indicators from a title.
func cleanTitle(title string) string {
	cleaned := title
	versionPatterns := []string{
		"remaster", "remastered", "deluxe", "bonus", "single",
		"album version", "radio edit", "original mix", "extended",
		"club mix", "remix", "live", "acoustic", "demo",
	}

	for {
		startParen := strings.LastIndex(cleaned, "(")
		endParen := strings.LastIndex(cleaned, ")")
		if startParen >= 0 && endParen > startParen {
			content := strings.ToLower(cleaned[startParen+1 : endParen])
			isVersionIndicator := false
			for _, pattern := range versionPatterns {
				if strings.Contains(content, pattern) {
					isVersionIndicator = true
					break
				}
			}
			if isVersionIndicator {
				cleaned = strings.TrimSpace(cleaned[:startParen]) + cleaned[endParen+1:]
				continue
			}
		}
		break
	}

	for {
		startBracket := strings.LastIndex(cleaned, "[")
		endBracket := strings.LastIndex(cleaned, "]")
		if startBracket >= 0 && endBracket > startBracket {
			content := strings.ToLower(cleaned[startBracket+1 : endBracket])
			isVersionIndicator := false
			for _, pattern := range versionPatterns {
				if strings.Contains(content, pattern) {
					isVersionIndicator = true
					break
				}
			}
			if isVersionIndicator {
				cleaned = strings.TrimSpace(cleaned[:startBracket]) + cleaned[endBracket+1:]
				continue
			}
		}
		break
	}

	dashPatterns := []string{
		" - remaster", " - remastered", " - single version", " - radio edit",
		" - live", " - acoustic", " - demo", " - remix",
	}
	for _, pattern := range dashPatterns {
		if strings.HasSuffix(strings.ToLower(cleaned), pattern) {
			cleaned = cleaned[:len(cleaned)-len(pattern)]
		}
	}

	for strings.Contains(cleaned, "  ") {
		cleaned = strings.ReplaceAll(cleaned, "  ", " ")
	}

	return strings.TrimSpace(cleaned)
}


