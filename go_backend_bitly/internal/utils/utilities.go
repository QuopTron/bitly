package utils

import (
	"crypto/sha1"
	"fmt"
	"strings"
	"unicode"
)

func NormalizeForMatch(text string) string {
	if text == "" {
		return ""
	}
	return NormalizeLooseTitle(CleanTitle(text))
}

func NormalizeSource(source string) string {
	if source == "" {
		return "builtin"
	}
	s := strings.TrimSpace(strings.ToLower(source))
	switch s {
	case "qobuz_kennyy", "qobuz-web", "qobuz":
		return "qobuz"
	case "spotify-web", "spotify:track", "spotify":
		return "spotify"
	case "tidal-web", "tidal":
		return "tidal"
	case "deezer":
		return "deezer"
	case "apple-music", "apple_music":
		return "apple-music"
	case "soundcloud":
		return "soundcloud"
	case "ytmusic-bitly", "ytmusic":
		return "ytmusic"
	case "pandora":
		return "pandora"
	case "amazon", "amazon_music":
		return "amazon"
	case "local":
		return "local"
	default:
		return s
	}
}

func NormalizeISRC(isrc string) string {
	return strings.ToUpper(strings.TrimSpace(isrc))
}

func NormalizeSpotifyID(id string) string {
	return strings.TrimSpace(id)
}

func MatchKeyFor(track, artist string) string {
	return fmt.Sprintf("%s|%s", NormalizeForMatch(track), NormalizeForMatch(artist))
}

func AlbumKeyFor(album, artist string) string {
	return fmt.Sprintf("%s|%s", NormalizeForMatch(album), NormalizeForMatch(artist))
}

func SanitizeFilename(name string) string {
	invalid := []string{"/", "\\", ":", "*", "?", "\"", "<", ">", "|"}
	result := name
	for _, ch := range invalid {
		result = strings.ReplaceAll(result, ch, "_")
	}
	result = strings.Trim(result, ". ")
	if result == "" {
		result = "unknown"
	}
	return result
}

func Truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}

func HashString(s string) string {
	h := sha1.Sum([]byte(s))
	return fmt.Sprintf("%x", h)
}

func IsWhitespace(s string) bool {
	for _, r := range s {
		if !unicode.IsSpace(r) {
			return false
		}
	}
	return true
}

type ResolvedTrackInfo struct {
	Title                string
	ArtistName           string
	ISRC                 string
	Duration             int
	SkipNameVerification bool
}
