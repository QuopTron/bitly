package search

import (
	"strings"
)

// splitTitleArtist tries to split a search query into (title, artist).
// Common patterns: "Artist - Title", "Title - Artist", "Title ft Artist",
// "Title by Artist". When no separator is found, returns ("", query) so
// the scorer uses full-query title matching.
func splitTitleArtist(q string) (string, string) {
	low := strings.ToLower(q)

	// "Artist - Title" pattern (most common in music searches)
	if idx := strings.Index(low, " - "); idx > 0 {
		return strings.TrimSpace(q[idx+3:]), strings.TrimSpace(q[:idx])
	}
	// "Title by Artist"
	if idx := strings.Index(low, " by "); idx >= 0 {
		return strings.TrimSpace(q[:idx]), strings.TrimSpace(q[idx+4:])
	}
	// "Title ft Artist" / "Title feat Artist"
	for _, sep := range []string{" ft ", " feat ", " featuring ", " ft. ", " feat. "} {
		if idx := strings.Index(low, sep); idx >= 0 {
			return strings.TrimSpace(q[:idx]), strings.TrimSpace(q[idx+len(sep):])
		}
	}
	// No separator — title-only search
	return q, ""
}

// isUploaderChannel returns true when an artist name looks like a YouTube /
// SoundCloud re-upload channel rather than a real artist (e.g. "Anna pham",
// "lyrics video", "VEVO", etc.).
func isUploaderChannel(artist string) bool {
	low := strings.ToLower(artist)
	channels := []string{
		"lyrics", "official", "vevo", "topic", "music",
		"video", "channel", "Records", "Entertainment",
	}
	for _, ch := range channels {
		if strings.Contains(low, strings.ToLower(ch)) {
			return true
		}
	}
	return false
}
