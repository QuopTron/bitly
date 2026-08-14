package gobackend

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"time"
)

// =========================================================================
// CACHE & COVERS — Flutter InfraMixin / SettingsMixin contract:
//   getStreamCacheStats ()
//   clearStreamCache ()
//   setStreamCacheMaxMb {mb}
//   getCoverPathForTrack {track_id, isrc, track_name, artist_name, cover_url}
//   saveCover {url}
//   deleteCover {url}
//   resetDatabase ()
// =========================================================================

var coversDir = ".covers"

// coversDirPath returns the covers directory, creating it if needed.
func coversDirPath() string {
	if downloadDir != "" {
		return filepath.Join(downloadDir, ".covers")
	}
	return coversDir
}

// CoversDir returns the absolute covers directory so the desktop server can
// serve the same files the backend writes.
func CoversDir() string {
	path := coversDirPath()
	if abs, err := filepath.Abs(path); err == nil {
		return abs
	}
	return path
}

// GetStreamCacheStats returns the cache stats for the settings UI: the
// combined size of the audio stream cache (.stream_cache/) and the covers
// (.covers/). Opening the settings screen also runs the opportunistic eviction
// of both caches, so the numbers shown are post-cleanup.
// Flutter contract: {total_size_bytes, file_count, size_mb, max_cache_mb,
// level_limit_mb, user_level, estimated_hours}.
func GetStreamCacheStats() string {
	levelLimit := streamCacheLevelLimitMB()
	maxMB := streamCacheMaxMB
	if maxMB <= 0 {
		maxMB = levelLimit
	}
	if maxMB > levelLimit {
		maxMB = levelLimit
	}
	evictStreamCache(streamCacheDirPath())
	evictCovers(coversDirPath())
	streamBytes, streamFiles := dirStats(streamCacheDirPath())
	coversBytes, coversFiles := dirStats(coversDirPath())
	streamMB := int(streamBytes / (1024 * 1024))
	out, _ := json.Marshal(map[string]interface{}{
		"total_size_bytes": streamBytes + coversBytes,
		"file_count":       streamFiles + coversFiles,
		"size_mb":          streamMB,
		"max_cache_mb":     maxMB,
		"level_limit_mb":   levelLimit,
		"user_level":       userLevelLabel(),
		// ~1h de audio por cada 100MB (estimación 320kbps).
		"estimated_hours": int(float64(streamMB) / 100.0),
	})
	return string(out)
}

// ClearStreamCache removes cached stream files AND covers (the two caches the
// app writes next to downloads). Files in use keep working (fd stays open).
func ClearStreamCache() string {
	removed := 0
	removed += clearDirFiles(streamCacheDirPath())
	removed += clearDirFiles(coversDirPath())
	out, _ := json.Marshal(map[string]interface{}{"removed": removed, "ok": true})
	return string(out)
}

func clearDirFiles(dir string) int {
	removed := 0
	if entries, err := os.ReadDir(dir); err == nil {
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			if err := os.Remove(filepath.Join(dir, e.Name())); err == nil {
				removed++
			}
		}
	}
	return removed
}

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
	// A cover saved during a download is keyed by the URL hash (SaveCover),
	// while likes may look it up by ISRC/track id. Try every known key so the
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
		path := filepath.Join(coversDirPath(), coverHash(key)+".jpg")
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
	filename := coverHash(params.URL) + ".jpg"
	path := filepath.Join(coversDirPath(), filename)
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
	evictCovers(coversDirPath())
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
	filename := coverHash(params.URL) + ".jpg"
	path := filepath.Join(coversDirPath(), filename)
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

func coverHash(key string) string {
	h := sha256.Sum256([]byte(key))
	return hex.EncodeToString(h[:16])
}

func dirStats(dir string) (bytes int64, count int) {
	if entries, err := os.ReadDir(dir); err == nil {
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			count++
			if info, err := e.Info(); err == nil {
				bytes += info.Size()
			}
		}
	}
	return
}

// coversLevelLimitMB returns the plan-based cap for the .covers dir. Covers
// are small but accumulate one per liked/downloaded track, so they get their
// own tighter budget instead of eating the stream-cache cap.
func coversLevelLimitMB() int {
	switch userLevelLabel() {
	case "lifetime":
		return 1000
	case "premium":
		return 500
	default:
		return 50
	}
}

// evictCovers bounds the covers dir to the plan's covers cap, deleting the
// oldest files first (same policy as evictStreamCache). Runs after each new
// cover is saved and whenever the settings screen is opened.
func evictCovers(dir string) {
	evictCoversLimit(dir, coversLevelLimitMB())
}

// evictCoversLimit is evictCovers with an explicit cap (injectable for tests).
func evictCoversLimit(dir string, limitMB int) {
	if limitMB <= 0 {
		return
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	type f struct {
		path string
		mod  time.Time
		size int64
	}
	var files []f
	var total int64
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		files = append(files, f{filepath.Join(dir, e.Name()), info.ModTime(), info.Size()})
		total += info.Size()
	}
	if len(files) == 0 {
		return
	}
	sort.Slice(files, func(i, j int) bool { return files[i].mod.Before(files[j].mod) })
	maxBytes := int64(limitMB) * 1024 * 1024
	const maxFiles = 5000
	for i := 0; i < len(files); i++ {
		remaining := len(files) - i
		if remaining <= maxFiles && total <= maxBytes {
			break
		}
		if os.Remove(files[i].path) == nil {
			total -= files[i].size
		}
	}
}

func userLevelLabel() string {
	if userMode == "free" {
		return "free"
	}
	if userMode == "lifetime" {
		return "lifetime"
	}
	if userMode != "" {
		return "premium"
	}
	if premiumChecker != nil && premiumChecker.IsPremium() {
		return "premium"
	}
	return "free"
}

func streamCacheLevelLimitMB() int {
	level := userLevelLabel()
	switch level {
	case "lifetime":
		return 5000
	case "premium":
		return 2000
	default:
		return 200
	}
}
