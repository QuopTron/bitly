package availability

import (
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func extractSpotifyID(spotifyURL string) string {
	parts := strings.Split(spotifyURL, "/track/")
	if len(parts) > 1 {
		idPart := parts[1]
		if idx := strings.Index(idPart, "?"); idx > 0 {
			idPart = idPart[:idx]
		}
		return idPart
	}
	return ""
}

func extractDeezerID(track *core.TrackMetadata) string {
	if track == nil {
		return ""
	}
	if deezerID, ok := strings.CutPrefix(strings.TrimSpace(track.SpotifyID), "deezer:"); ok {
		deezerID = strings.TrimSpace(deezerID)
		if deezerID != "" {
			return deezerID
		}
	}
	if deezerID := extractDeezerIDFromURL(strings.TrimSpace(track.ExternalURL)); deezerID != "" {
		return deezerID
	}
	return ""
}

func extractDeezerIDFromURL(deezerURL string) string {
	parts := strings.Split(deezerURL, "/")
	if len(parts) > 0 {
		lastPart := parts[len(parts)-1]
		if idx := strings.Index(lastPart, "?"); idx > 0 {
			lastPart = lastPart[:idx]
		}
		return lastPart
	}
	return ""
}
