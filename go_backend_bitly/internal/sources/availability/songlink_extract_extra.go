package availability

import (
	"net/url"
	"strings"
)

func extractQobuzID(qobuzURL string) string {
	if qobuzURL == "" {
		return ""
	}
	if strings.Contains(qobuzURL, "/track/") {
		parts := strings.Split(qobuzURL, "/track/")
		if len(parts) > 1 {
			idPart := parts[1]
			if idx := strings.Index(idPart, "?"); idx > 0 {
				idPart = idPart[:idx]
			}
			if idx := strings.Index(idPart, "/"); idx > 0 {
				idPart = idPart[:idx]
			}
			return strings.TrimSpace(idPart)
		}
	}
	if strings.Contains(qobuzURL, "trackId=") {
		parts := strings.Split(qobuzURL, "trackId=")
		if len(parts) > 1 {
			idPart := parts[1]
			if idx := strings.Index(idPart, "&"); idx > 0 {
				idPart = idPart[:idx]
			}
			return strings.TrimSpace(idPart)
		}
	}
	return ""
}

func extractTidalID(tidalURL string) string {
	if tidalURL == "" {
		return ""
	}
	if strings.Contains(tidalURL, "/track/") {
		parts := strings.Split(tidalURL, "/track/")
		if len(parts) > 1 {
			idPart := parts[1]
			if idx := strings.Index(idPart, "?"); idx > 0 {
				idPart = idPart[:idx]
			}
			if idx := strings.Index(idPart, "/"); idx > 0 {
				idPart = idPart[:idx]
			}
			return strings.TrimSpace(idPart)
		}
	}
	return ""
}

func extractYouTubeID(youtubeURL string) string {
	if youtubeURL == "" {
		return ""
	}
	if strings.Contains(youtubeURL, "youtu.be/") {
		parts := strings.Split(youtubeURL, "youtu.be/")
		if len(parts) >= 2 {
			idPart := parts[1]
			if idx := strings.Index(idPart, "?"); idx > 0 {
				idPart = idPart[:idx]
			}
			if idx := strings.Index(idPart, "&"); idx > 0 {
				idPart = idPart[:idx]
			}
			return strings.TrimSpace(idPart)
		}
	}
	parsed, err := url.Parse(youtubeURL)
	if err != nil {
		return ""
	}
	if v := parsed.Query().Get("v"); v != "" {
		return v
	}
	if strings.Contains(parsed.Path, "/embed/") {
		parts := strings.Split(parsed.Path, "/embed/")
		if len(parts) >= 2 {
			return strings.Split(parts[1], "/")[0]
		}
	}
	return ""
}
