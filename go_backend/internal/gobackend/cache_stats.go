package gobackend

import (
	"encoding/json"
	"os"
	"path/filepath"
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
func rutaDirPortadas() string {
	if downloadDir != "" {
		return filepath.Join(downloadDir, ".covers")
	}
	return coversDir
}

// CoversDir returns the absolute covers directory so the desktop server can
// serve the same files the backend writes.
func CoversDir() string {
	path := rutaDirPortadas()
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
	evictarCacheStream(streamCacheDirPath())
	evictarPortadas(rutaDirPortadas())
	streamBytes, streamFiles := statsDir(streamCacheDirPath())
	coversBytes, coversFiles := statsDir(rutaDirPortadas())
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
	removed += limpiarArchivosDir(streamCacheDirPath())
	removed += limpiarArchivosDir(rutaDirPortadas())
	out, _ := json.Marshal(map[string]interface{}{"removed": removed, "ok": true})
	return string(out)
}

func limpiarArchivosDir(dir string) int {
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
