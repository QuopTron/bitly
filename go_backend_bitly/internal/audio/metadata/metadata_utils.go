package metadata

import (
	"path/filepath"
	"strings"
)

// NormalizeISRC normalizes an ISRC string (uppercase, stripped spaces).
func NormalizeISRC(value string) string {
	return strings.ToUpper(strings.TrimSpace(value))
}

// NormalizeSpotifyID normalizes a Spotify ID (trim whitespace).
func NormalizeSpotifyID(value string) string {
	return strings.TrimSpace(value)
}

// NormalizeOptionalString returns empty string if value is "null" or "undefined".
func NormalizeOptionalString(value string) string {
	v := strings.TrimSpace(value)
	if v == "" || v == "null" || v == "undefined" {
		return ""
	}
	return v
}

// NormalizeCoverReference normalizes a cover URL reference.
func NormalizeCoverReference(value string) string {
	return strings.TrimSpace(value)
}

// NormalizeRemoteHTTPUrl ensures a URL has a scheme.
func NormalizeRemoteHTTPUrl(value string) string {
	v := strings.TrimSpace(value)
	if v == "" {
		return ""
	}
	if !strings.HasPrefix(v, "http://") && !strings.HasPrefix(v, "https://") {
		v = "https://" + v
	}
	return v
}

// SanitizeFolderName removes characters invalid in folder names.
func SanitizeFolderName(name string) string {
	name = strings.TrimSpace(name)
	invalid := []string{"/", "\\", ":", "*", "?", "\"", "<", ">", "|", "\x00"}
	for _, ch := range invalid {
		name = strings.ReplaceAll(name, ch, "_")
	}
	return strings.TrimSpace(name)
}

// MatchKeyFor generates a match key for track+artist deduplication.
func MatchKeyFor(track, artist string) string {
	return NormalizeISRC(track + artist)
}

// AlbumKeyFor generates a match key for album+artist deduplication.
func AlbumKeyFor(album, artist string) string {
	return NormalizeISRC(album + artist)
}

// HasEmbeddedLyricsMetadata checks if a metadata struct has lyrics content.
func HasEmbeddedLyricsMetadata(meta *AudioMetadata) bool {
	if meta == nil {
		return false
	}
	lyrics := strings.TrimSpace(meta.Lyrics)
	comment := strings.TrimSpace(meta.Comment)
	return lyrics != "" || comment != ""
}

// BuildPathMatchKeys builds matching keys from a file path.
func BuildPathMatchKeys(filePath string) []string {
	base := strings.TrimSuffix(filepath.Base(filePath), filepath.Ext(filePath))
	parts := strings.Split(base, " - ")
	if len(parts) < 2 {
		return []string{NormalizeISRC(base)}
	}
	return []string{
		NormalizeISRC(parts[len(parts)-1] + parts[0]),
		NormalizeISRC(base),
	}
}
