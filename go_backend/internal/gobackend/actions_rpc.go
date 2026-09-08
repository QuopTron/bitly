package gobackend

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/download"
)

// =========================================================================
// ACTIONS — Flutter ActionsMixin contract:
//   likeItem {item_id, liked}
//   downloadItem {item_id}
//   getAllDownloadProgress ()
//   downloadByStrategy {request}
//   initItemProgress {item_id, track_name, artist_name}
//   estimateTrackFileSize {duration_ms, quality}
//   setDownloadDirectory {path}
//   setBackendConfig {mode, stream_cache_max_mb}
// =========================================================================

// LikeItem acknowledges the like toggle (persistence lives in Flutter/Drift).
func LikeItem(payload string) string {
	return `{"ok":true}`
}

// DownloadItem triggers a download for a track by item_id.
func DownloadItem(payload string) string {
	var params struct {
		ItemID string `json:"item_id"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil || params.ItemID == "" {
		return jsonErrorString("falta item_id")
	}
	if downloadOrch == nil {
		return jsonErrorString("no inicializado")
	}
	// Fire-and-forget: the fallback can run for tens of seconds, and the
	// Android bridge serializes RPCs on one thread — a synchronous download
	// would stall every search/poll queued behind it (search then times out
	// and shows "sin resultados"). Progress is tracked; Flutter polls
	// getAllDownloadProgress for the outcome.
	go func() { _ = downloadOrch.Download(download.Request{ItemID: params.ItemID}) }()
	return `{"ok":true}`
}

// GetAllDownloadProgress returns all active download progress entries.
// Format: {"items": {itemId: {...}}} — matches the DownloadCubit polling contract.
func GetAllDownloadProgress() string {
	if downloadOrch == nil {
		return `{"items":{}}`
	}
	items := downloadOrch.Progress().GetAll()
	m := make(map[string]interface{}, len(items))
	for _, it := range items {
		m[it.ItemID] = it
	}
	data, _ := json.Marshal(map[string]interface{}{"items": m})
	return string(data)
}

// DownloadByStrategy dispatches a download from the strategy JSON sent by Flutter.
// Flutter contract: {request: "<strategy JSON string>"}.
func DownloadByStrategy(payload string) string {
	var params struct {
		Request string `json:"request"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil || params.Request == "" {
		return jsonErrorString("falta request")
	}
	var raw map[string]interface{}
	if err := json.Unmarshal([]byte(params.Request), &raw); err != nil {
		return jsonErrorString("request inválido")
	}
	outDir := strOf(raw, "output_dir", "outputDir")
	if outDir == "" {
		outDir = downloadDir
	}
	// Always map from the raw (snake_case) strategy payload. The strategy keys
	// ("item_id", "track_title", ...) never match the Request camelCase struct
	// tags, so a direct unmarshal only fills fields whose tags collide (e.g.
	// "isrc") and silently drops item_id/track_id/title/source — which then
	// Descargas como un nameless "desconocido" archivo. construyendo de raw mantiene cada
	// field intact regardless of key casing.
	req := download.Request{
		ItemID:     strOf(raw, "item_id", "itemId"),
		Title:      strOf(raw, "track_title", "title", "track_name", "name"),
		Artist:     strOf(raw, "artist_name", "artist"),
		Album:      strOf(raw, "album_name", "album"),
		ISRC:       strOf(raw, "isrc"),
		Provider:   strOf(raw, "source", "provider"),
		TrackID:    strOf(raw, "track_id", "trackId"),
		Quality:    strOf(raw, "quality"),
		OutputDir:  outDir,
		Type:       strOf(raw, "type"),
		LyricsSrc:  strOf(raw, "source"),
		SpotifyID:  strOf(raw, "spotify_id", "spotifyId"),
		DeezerID:   strOf(raw, "deezer_id", "deezerId"),
		TidalID:    strOf(raw, "tidal_id", "tidalId"),
		QobuzID:    strOf(raw, "qobuz_id", "qobuzId"),
		DurationMS: strInt(raw, "duration_ms", "durationMs"),
	}
	if downloadOrch == nil {
		return jsonErrorString("no inicializado")
	}
	switch req.Type {
	case "lyrics":
		return descargarLetrasADisco(req)
	case "video":
		return descargarVideoADisco(req)
	}
	// Audio downloads run in the background. The multi-provider fallback can
	// hold the bridge's single RPC thread for ~50s, and any search/poll queued
	// behind it exceeded Flutter's 60s RPC timeout and silently returned
	// "sin resultados". The client already polls getAllDownloadProgress for the
	// outcome, so nothing here needs the synchronous *Result.
	go func() {
		// Si este canción era ya transmitido (un playable copy existe en the
		// stream cache and satisfies the requested quality), copy it to the
		// Descargas carpeta en su lugar de re-walking cada proveedor y
		// re-downloading the same audio — the download completes instantly.
		if reuseStreamCacheForDownload(req) {
			return
		}
		_ = downloadOrch.Download(req)
	}()
	return fmt.Sprintf(`{"itemId":%q,"queued":true}`, req.ItemID)
}
