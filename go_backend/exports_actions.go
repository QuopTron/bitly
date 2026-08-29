package gobackend

import (
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/extensions"
	"github.com/zarz/bitly/go_backend/internal/streaming"
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
		return jsonErrorStr("falta item_id")
	}
	if downloadOrch == nil {
		return jsonErrorStr("no inicializado")
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
		return jsonErrorStr("falta request")
	}
	var raw map[string]interface{}
	if err := json.Unmarshal([]byte(params.Request), &raw); err != nil {
		return jsonErrorStr("request inválido")
	}
	outDir := strOf(raw, "output_dir", "outputDir")
	if outDir == "" {
		outDir = downloadDir
	}
	// Always map from the raw (snake_case) strategy payload. The strategy keys
	// ("item_id", "track_title", ...) never match the Request camelCase struct
	// tags, so a direct unmarshal only fills fields whose tags collide (e.g.
	// "isrc") and silently drops item_id/track_id/title/source — which then
	// downloads as a nameless "unknown" file. Building from raw keeps every
	// field intact regardless of key casing.
	req := download.Request{
		ItemID:    strOf(raw, "item_id", "itemId"),
		Title:     strOf(raw, "track_title", "title", "track_name", "name"),
		Artist:    strOf(raw, "artist_name", "artist"),
		Album:     strOf(raw, "album_name", "album"),
		ISRC:      strOf(raw, "isrc"),
		Provider:  strOf(raw, "source", "provider"),
		TrackID:   strOf(raw, "track_id", "trackId"),
		Quality:   strOf(raw, "quality"),
		OutputDir: outDir,
		Type:      strOf(raw, "type"),
		LyricsSrc: strOf(raw, "source"),
		SpotifyID: strOf(raw, "spotify_id", "spotifyId"),
		DeezerID:  strOf(raw, "deezer_id", "deezerId"),
		TidalID:   strOf(raw, "tidal_id", "tidalId"),
		QobuzID:   strOf(raw, "qobuz_id", "qobuzId"),
		DurationMS: strInt(raw, "duration_ms", "durationMs"),
	}
	if downloadOrch == nil {
		return jsonErrorStr("no inicializado")
	}
	switch req.Type {
	case "lyrics":
		return downloadLyricsToDisk(req)
	case "video":
		return downloadVideoToDisk(req)
	}
	// Audio downloads run in the background. The multi-provider fallback can
	// hold the bridge's single RPC thread for ~50s, and any search/poll queued
	// behind it exceeded Flutter's 60s RPC timeout and silently returned
	// "sin resultados". The client already polls getAllDownloadProgress for the
	// outcome, so nothing here needs the synchronous *Result.
	go func() {
		_ = downloadOrch.Download(req)
	}()
	return fmt.Sprintf(`{"itemId":%q,"queued":true}`, req.ItemID)
}

// downloadLyricsToDisk fetches lyrics and writes a .lrc sidecar next to the
// audio file, matching the filename Flutter expects: lyrics_{sha1(id)}.{lrc,txt}.
func downloadLyricsToDisk(req download.Request) string {
	outDir := req.OutputDir
	if outDir == "" {
		outDir = download.GlobalOutputDir()
	}
	if outDir == "" || lyricsClient == nil || req.TrackID == "" {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"letras: falta outDir o trackID"}`
	}
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"` + err.Error() + `"}`
	}
	lyr, err := lyricsClient.GetLyrics(req.Title, req.Artist, 0)
	if err != nil || lyr == nil {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"letras no encontradas"}`
	}
	text := lyr.SyncedLyrics
	if text == "" {
		text = lyr.PlainLyrics
	}
	if text == "" {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"instrumental sin letras"}`
	}
	hash := sha1Hex(req.TrackID)
	base := filepath.Join(outDir, "lyrics_"+hash)
	lrcPath := base + ".lrc"
	txtPath := base + ".txt"
	if err := writeFileAtomic(lrcPath, text); err != nil {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"` + err.Error() + `"}`
	}
	_ = writeFileAtomic(txtPath, text)
	return `{"itemId":"` + req.ItemID + `","success":true,"filePath":"` + lrcPath + `","title":"` + req.Title + `","artist":"` + req.Artist + `"}`
}

// downloadVideoToDisk resolves a video stream and writes {Artist} - {Title}.mp4.
func downloadVideoToDisk(req download.Request) string {
	outDir := req.OutputDir
	if outDir == "" {
		outDir = download.GlobalOutputDir()
	}
	if outDir == "" || req.TrackID == "" {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"video: falta outDir o trackID"}`
	}
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"` + err.Error() + `"}`
	}
	videoID := req.TrackID
	// The track ID comes from any provider (Spotify/Deezer/...). YouTube needs
	// a real video ID, so when the caller gives us a foreign ID plus the track
	// name, search YouTube first and use the best match (video is a separate
	// visual feature — never the audio stream).
	if !strings.HasPrefix(videoID, "yt:") && req.Title != "" {
		query := req.Title
		if req.Artist != "" {
			query = req.Title + " " + req.Artist
		}
		if p := reg.Get("youtube"); p != nil {
			if results, serr := p.SearchTracks(query, 1); serr == nil && len(results) > 0 && results[0].ID != "" {
				videoID = results[0].ID // "yt:<videoID>"
			}
		}
	}
	if videoID == "" {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"video: sin ID de video"}`
	}
	streamURL, err := downloadOrch.ResolveVideoURL(videoID, req.Quality)
	if err != nil || streamURL == "" {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"video: no se pudo resolver URL"}`
	}
	name := "video_" + req.TrackID
	if req.Artist != "" && req.Title != "" {
		name = req.Artist + " - " + req.Title
	}
	path := filepath.Join(outDir, sanitizeFileName(name)+".mp4")
	if err := downloadOrch.WriteURLToFile(streamURL, path); err != nil {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"` + err.Error() + `"}`
	}
	return `{"itemId":"` + req.ItemID + `","success":true,"filePath":"` + path + `","title":"` + req.Title + `","artist":"` + req.Artist + `"}`
}

// writeFileAtomic writes content to path via a temp file + rename.
func writeFileAtomic(path, content string) error {
	tmp := path + ".dl-tmp"
	if err := os.WriteFile(tmp, []byte(content), 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// sha1Hex returns the hex SHA-1 of a string, matching Flutter's lyrics_ prefix.
func sha1Hex(s string) string {
	h := sha1.Sum([]byte(s))
	return hex.EncodeToString(h[:])
}

// sanitizeFileName strips characters unsafe for filesystems.
func sanitizeFileName(s string) string {
	s = strings.TrimSpace(s)
	re := regexp.MustCompile(`[\\/:*?"<>|]`)
	s = re.ReplaceAllString(s, "_")
	s = strings.TrimRight(s, ". ")
	if s == "" {
		return "unknown"
	}
	return s
}

// InitItemProgress registers a progress entry so Flutter can poll it.
func InitItemProgress(payload string) string {
	var params struct {
		ItemID     string `json:"item_id"`
		TrackName  string `json:"track_name"`
		ArtistName string `json:"artist_name"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonErrorStr("payload inválido")
	}
	if downloadOrch == nil {
		return jsonErrorStr("no inicializado")
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
	bitrate := bitrateForQuality(params.Quality)
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
		return jsonErrorStr("payload inválido")
	}
	downloadDir = params.Path
	download.SetGlobalOutputDir(params.Path)
	// Persist Cloudflare signed sessions (deezer/amazon/qobuz/tidal-web) under
	// the writable app dir so a verified session survives restarts (embedded
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
		return jsonErrorStr("payload inválido")
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

// SetDownloadProviderPriority configures the ordered list of download providers
// used for fallback (best-first), mirroring SpotiFLAC's SetProviderPriority.
// payload: {"providers": ["amazon", "deezer", ...]}. Omitted/empty restores the
// built-in default order.
func SetDownloadProviderPriority(payload string) string {
	var params struct {
		Providers []string `json:"providers"`
	}
	if payload == "" {
		return `{"ok":true}`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonErrorStr("payload inválido")
	}
	if downloadOrch == nil {
		return `{"ok":false,"error":"orchestrator no inicializado"}`
	}
	downloadOrch.SetDownloadProviderPriority(params.Providers)
	return `{"ok":true}`
}

// strOf reads the first non-empty string from a set of JSON keys.
func strOf(m map[string]interface{}, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			if s, ok := v.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

// strInt reads the first non-zero int from a set of JSON keys.
func strInt(m map[string]interface{}, keys ...string) int {
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			switch n := v.(type) {
			case float64:
				return int(n)
			case int64:
				return int(n)
			case int:
				return n
			case string:
				if out, err := strconv.Atoi(n); err == nil {
					return out
				}
			}
		}
	}
	return 0
}

// bitrateForQuality returns the approximate bitrate (kbps) for a quality label.
func bitrateForQuality(q string) int {
	switch q {
	case "FLAC", "LOSSLESS", "HI_RES":
		return 1000
	case "320", "MP3_320":
		return 320
	case "256":
		return 256
	case "192":
		return 192
	case "128", "MP3_128":
		return 128
	default:
		return 1000
	}
}

// GetProviderHealthStatus returns cooldown status of all providers.
func GetProviderHealthStatus() string {
	status := cooldown.GetAllStatus()
	data, _ := json.Marshal(status)
	if data == nil {
		return "[]"
	}
	return string(data)
}
