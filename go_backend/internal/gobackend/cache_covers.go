package gobackend

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// SetStreamCacheMaxMb sets the cache limit, capped by the user's plan.
func SetStreamCacheMaxMb(payload string) string {
	var params struct {
		MB int `json:"mb"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"ok":false,"error":"payload inválido"}`
	}
	limit := streamCacheLevelLimitMB()
	if params.MB > limit {
		params.MB = limit
	}
	streamCacheMaxMB = params.MB
	out, _ := json.Marshal(map[string]interface{}{
		"mb":             params.MB,
		"level_limit_mb": limit,
		"ok":             true,
	})
	return string(out)
}

// GetCoverPathForTrack returns a local cover path if the cover is already cached.
func GetCoverPathForTrack(payload string) string {
	var params struct {
		TrackID   string `json:"track_id"`
		ISRC      string `json:"isrc"`
		TrackName string `json:"track_name"`
		Artist    string `json:"artist_name"`
		CoverURL  string `json:"cover_url"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return ""
	}
	// A cover guardado durante un descarga es keyed por el URL hash (SaveCover),
	// Mientras likes puede look se arriba por isrc/canción id. try cada known clave so the
	// locally saved cover is always recovered.
	var keys []string
	if params.ISRC != "" {
		keys = append(keys, params.ISRC)
	}
	if params.TrackID != "" {
		keys = append(keys, params.TrackID)
	}
	if params.CoverURL != "" {
		keys = append(keys, params.CoverURL)
	}
	if params.TrackName != "" {
		keys = append(keys, params.TrackName+"|"+params.Artist)
	}
	for _, key := range keys {
		path := filepath.Join(rutaDirPortadas(), hashPortada(key)+".jpg")
		if _, err := os.Stat(path); err == nil {
			abs, _ := filepath.Abs(path)
			return abs
		}
	}
	return ""
}

// SaveCover downloads a cover image to the local covers dir and returns the
// absolute path of the saved file (empty string on failure). The absolute path
// is used directly by the UI as a local file path, so covers keep working on
// platforms without the desktop HTTP server (e.g. Android).
func SaveCover(payload string) string {
	var params struct {
		URL string `json:"url"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil || params.URL == "" {
		return ""
	}
	filename := hashPortada(params.URL) + ".jpg"
	path := filepath.Join(rutaDirPortadas(), filename)
	abs, _ := filepath.Abs(path)
	if _, err := os.Stat(path); err == nil {
		return abs
	}
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return ""
	}

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Get(params.URL)
	if err != nil || resp == nil {
		return ""
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return ""
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, 8*1024*1024))
	if err != nil || len(data) == 0 {
		return ""
	}
	if err := os.WriteFile(path, data, 0644); err != nil {
		return ""
	}
	// New cover on disk: enforce the covers cap (oldest first) so a big liked
	// library never fills the storage with portadas.
	evictarPortadas(rutaDirPortadas())
	return abs
}

// DeleteCover removes a cached cover file.
func DeleteCover(payload string) string {
	var params struct {
		URL string `json:"url"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil || params.URL == "" {
		return `{"ok":false}`
	}
	filename := hashPortada(params.URL) + ".jpg"
	path := filepath.Join(rutaDirPortadas(), filename)
	os.Remove(path)
	return `{"ok":true}`
}

// ResetDatabase resets in-memory state (Flutter persists Drift locally).
func ResetDatabase() string {
	userMode = ""
	downloadDir = ""
	streamCacheMaxMB = 0
	return `{"ok":true}`
}

// =========================================================================
// HELPERS
// =========================================================================
