package gobackend

import (
	"encoding/json"
	"path/filepath"

	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/extensions"
	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// InitItemProgress registers a progress entry so Flutter can poll it.
func InitItemProgress(payload string) string {
	var params struct {
		ItemID     string `json:"item_id"`
		TrackName  string `json:"track_name"`
		ArtistName string `json:"artist_name"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonErrorString("payload inválido")
	}
	if downloadOrch == nil {
		return jsonErrorString("no inicializado")
	}
	downloadOrch.Progress().Add(params.ItemID, params.TrackName, "")
	return `{"ok":true}`
}

// EstimateTrackFileSize estimates the file size for a track at a given quality.
// Returns {estimatedBytes, quality, durationMs}.
func EstimateTrackFileSize(payload string) string {
	var params struct {
		DurationMs int    `json:"duration_ms"`
		Quality    string `json:"quality"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"estimatedBytes":0,"quality":"FLAC","durationMs":0}`
	}
	bitrate := bitrateParaCalidad(params.Quality)
	seconds := float64(params.DurationMs) / 1000.0
	estimated := int64(float64(bitrate) / 8.0 * seconds)
	out, _ := json.Marshal(map[string]interface{}{
		"estimatedBytes": estimated,
		"quality":        params.Quality,
		"durationMs":     params.DurationMs,
	})
	return string(out)
}

// SetDownloadDirectory stores the user's download dir in memory.
func SetDownloadDirectory(payload string) string {
	var params struct {
		Path string `json:"path"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonErrorString("payload inválido")
	}
	downloadDir = params.Path
	download.SetGlobalOutputDir(params.Path)
	// Persist Cloudflare signed sessions (deezer/amazon/qobuz/tidal-web) under
	// el writable aplicación dir so un verificado sesión survives restarts (embedded
	// sandboxes otherwise use "." on Android and can't write).
	extensions.SetSignedSessionDataDir(filepath.Join(params.Path, ".bitly_sessions"))
	return `{"ok":true}`
}

// SetBackendConfig syncs user mode + stream cache limits into memory.
func SetBackendConfig(payload string) string {
	var params struct {
		Mode                string `json:"mode"`
		StreamCacheMax      int    `json:"stream_cache_max_mb"`
		DownloadConcurrency int    `json:"download_concurrency"`
		StreamChunkSize     int    `json:"stream_chunk_size"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonErrorString("payload inválido")
	}
	if params.Mode != "" {
		userMode = params.Mode
	}
	if params.StreamCacheMax > 0 {
		streamCacheMaxMB = params.StreamCacheMax
	}
	if params.DownloadConcurrency > 0 && downloadOrch != nil {
		downloadOrch.SetConcurrency(params.DownloadConcurrency)
	}
	if params.StreamChunkSize > 0 {
		streaming.SetChunkSize(params.StreamChunkSize)
	}
	return `{"ok":true}`
}

// SetDownloadProviderPriority configura la lista ordenada de proveedores de
// descarga para el respaldo (mejor-primero), como el SetProviderPriority de
// SpotiFLAC. payload: {"providers": ["amazon", "deezer", ...]}. Si se omite
// o va vacio, restaura el orden predeterminado.
func SetDownloadProviderPriority(payload string) string {
	var params struct {
		Providers []string `json:"providers"`
	}
	if payload == "" {
		return `{"ok":true}`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonErrorString("payload inválido")
	}
	if downloadOrch == nil {
		return `{"ok":false,"error":"orchestrator no inicializado"}`
	}
	downloadOrch.SetDownloadProviderPriority(params.Providers)
	return `{"ok":true}`
}
