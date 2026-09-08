package cache

import (
	"os"
	"path/filepath"
	"strings"
)

// ═══════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════

func isAudioFile(path string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	switch ext {
	case ".flac", ".mp3", ".m4a", ".mp4", ".m4b", ".ogg", ".opus", ".wav", ".aiff", ".aif":
		return true
	}
	return false
}

func cleanString(data []byte) string {
	if len(data) == 0 {
		return ""
	}
	// Skip encoding byte for ID3v2 text frames
	if data[0] == 0 || data[0] == 3 { // ISO-8859-1 or UTF-8
		return strings.TrimSpace(string(data[1:]))
	}
	if data[0] == 1 && len(data) >= 3 { // UTF-16 with BOM
		if data[1] == 0xFE && data[2] == 0xFF {
			// UTF-16 BE
			return strings.TrimSpace(string(data[3:]))
		}
		if data[1] == 0xFF && data[2] == 0xFE {
			// UTF-16 LE
			return strings.TrimSpace(string(data[3:]))
		}
	}
	return strings.TrimSpace(string(data[1:]))
}

func findFileByTrackID(dir, trackID string) string {
	base := strings.TrimSuffix(trackID, filepath.Ext(trackID))
	entries, err := os.ReadDir(dir)
	if err != nil {
		return ""
	}
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := strings.TrimSuffix(e.Name(), filepath.Ext(e.Name()))
		if strings.EqualFold(name, base) || strings.Contains(e.Name(), trackID) {
			return filepath.Join(dir, e.Name())
		}
	}
	return ""
}

func scanForISRC(dir, isrc string) string {
	// Quick check: if the file exists with ISRC as name
	candidate := filepath.Join(dir, isrc+".flac")
	if _, err := os.Stat(candidate); err == nil {
		return candidate
	}
	candidate = filepath.Join(dir, isrc+".mp3")
	if _, err := os.Stat(candidate); err == nil {
		return candidate
	}
	return ""
}
