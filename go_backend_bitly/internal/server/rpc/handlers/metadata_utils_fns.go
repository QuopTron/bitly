package handlers

import (
	"fmt"
	"strings"
)

func hasOnlyM4AReplayGainFields(fields map[string]string) bool {
	allowed := map[string]struct{}{
		"replaygain_track_gain": {},
		"replaygain_track_peak": {},
		"replaygain_album_gain": {},
		"replaygain_album_peak": {},
	}
	hasReplayGain := false
	for key, value := range fields {
		if strings.TrimSpace(value) == "" {
			continue
		}
		if _, ok := allowed[strings.ToLower(strings.TrimSpace(key))]; ok {
			hasReplayGain = true
			continue
		}
		return false
	}
	return hasReplayGain
}

func buildFilenameFromTemplate(template string, metadata map[string]interface{}) string {
	if template == "" {
		return "unknown"
	}
	replacements := map[string]string{
		"{title}":       strVal(metadata, "title"),
		"{artist}":      strVal(metadata, "artist"),
		"{album}":       strVal(metadata, "album"),
		"{track}":       fmt.Sprintf("%02d", intVal(metadata, "track_number")),
		"{tracknumber}": fmt.Sprintf("%02d", intVal(metadata, "track_number")),
		"{disc}":        fmt.Sprintf("%d", intVal(metadata, "disc_number")),
		"{isrc}":        strVal(metadata, "isrc"),
		"{year}":        strVal(metadata, "year"),
		"{date}":        strVal(metadata, "date"),
	}
	result := template
	for placeholder, value := range replacements {
		result = strings.ReplaceAll(result, placeholder, value)
	}
	return sanitizeFilename(result)
}

func strVal(m map[string]interface{}, key string) string {
	v, _ := m[key].(string)
	return v
}

func intVal(m map[string]interface{}, key string) int {
	switch v := m[key].(type) {
	case float64:
		return int(v)
	case int:
		return v
	default:
		return 0
	}
}

func sanitizeFilename(name string) string {
	name = strings.TrimSpace(name)
	invalid := []string{"/", "\\", ":", "*", "?", "\"", "<", ">", "|", "\x00"}
	for _, ch := range invalid {
		name = strings.ReplaceAll(name, ch, "_")
	}
	return strings.TrimSpace(name)
}
