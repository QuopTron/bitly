package gobackend

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"time"

	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// =========================================================================
// STREAMING
// =========================================================================

func GetStreamURL(payload string) string {
	var params struct {
		ProviderName string `json:"providerName"`
		TrackID      string `json:"trackID"`
		Quality      string `json:"quality"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	url, err := p.GetStreamURL(params.TrackID, params.Quality)
	if err != nil {
		return jsonError(err)
	}
	return `{"url":"` + url + `"}`
}

// StartStreamingServer starts an HTTP proxy for audio streaming (desktop).
func StartStreamingServer(port int) string {
	if streamer == nil {
		streamer = streaming.NewStreamer()
	}
	addr, err := streamer.StartServer(port)
	if err != nil {
		return jsonError(err)
	}
	return `{"url":"` + addr + `"}`
}

// StopStreamingServer stops the streaming HTTP server.
func StopStreamingServer() string {
	if streamer == nil {
		return `{"ok":true}`
	}
	if err := streamer.StopServer(); err != nil {
		return jsonError(err)
	}
	return `{"ok":true}`
}

// GetStreamPackage returns a complete stream package: audio URL + metadata + lyrics + cover.
// Hace fallback entre providers si el especificado no tiene stream.
func GetStreamPackage(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		PreferredProvider string `json:"preferredProvider"`
		TrackID           string `json:"trackID"`
		Quality           string `json:"quality"`
		FetchLyrics       string `json:"fetchLyrics"`
		TrackName         string `json:"trackName"`
		ArtistName        string `json:"artistName"`
		ISRC              string `json:"isrc"`
		DurationMS        int    `json:"durationMs"`
		AllowFallback     bool   `json:"allowFallback"`
		// Cross-provider ids from detail views (album/artist/playlist). Detail
		// tracks carry these so ANY extension can resolve immediately via
		// CheckAvailability instead of a slow name search.
		SpotifyID string `json:"spotifyId"`
		DeezerID  string `json:"deezerId"`
		TidalID   string `json:"tidalId"`
		QobuzID   string `json:"qobuzId"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	fetchL := params.FetchLyrics == "true" || params.FetchLyrics == "1"

	// Real playback (AllowFallback=true): the middleware serves the actual file
	// downloaded to the stream cache — decrypted from DRM when needed and
	// transformed to the user's chosen quality — so media_kit plays the
	// "producida" copy instead of a low-bitrate direct stream. The direct-stream
	// path below is the fallback for when no provider can yield a high-quality
	// file.
	if params.AllowFallback {
		out := streamFallbackDownload(params.TrackID, params.Quality, params.PreferredProvider, params.TrackName, params.ArtistName, params.ISRC, params.DurationMS, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID)
		if out.encrypted != nil {
			return streamEncryptedJSON(out.encrypted, params.PreferredProvider)
		}
		if out.fileURL != "" {
			pkg := &streaming.StreamPackage{
				AudioURL: out.fileURL,
				Provider: "fallback",
				Quality:  params.Quality,
			}
			data, _ := json.Marshal(pkg)
			return string(data)
		}
		if out.err != nil {
			// The fallback download exhausted every provider and failed.
			// Before surfacing the structured error, try the direct streaming
			// path (getDownloadUrl over http(s)) as a genuine LAST resort:
			// some tracks only exist as a direct web stream and a playable
			// URL beats silence. Bounded to 40s so the total RPC stays inside
			// the 180s Android window (the orchestrator already burned up to
			// maxFallbackDuration).
			done := make(chan *streaming.StreamPackage, 1)
			go func() {
				pkg, err := streaming.GetStreamPackage(reg, lyricsClient, params.PreferredProvider, params.TrackID, params.Quality, fetchL, params.TrackName, params.ArtistName)
				if err == nil && pkg != nil && pkg.AudioURL != "" {
					done <- pkg
				} else {
					done <- nil
				}
			}()
			select {
			case pkg := <-done:
				if pkg != nil {
					data, _ := json.Marshal(pkg)
					return string(data)
				}
			case <-time.After(40 * time.Second):
			}
			// Everything failed. Surface the structured error directly — it
			// carries errorType/service naming the provider that actually
			// needs verification (e.g. amazon VERIFY_REQUIRED).
			return streamFallbackErrorJSON(out.err, out)
		}
	}

	pkg, err := streaming.GetStreamPackage(reg, lyricsClient, params.PreferredProvider, params.TrackID, params.Quality, fetchL, params.TrackName, params.ArtistName)
	if err != nil && !params.AllowFallback {
		// Background preloads (feed/queue prefetch) skip the download fallback
		// so they don't trigger full audio downloads for every non-streamable
		// track. The player re-resolves with fallback when the user taps play.
		return jsonError(err)
	}
	if err != nil {
		// Last resort: only download-to-cache if the direct resolve above failed
		// (the AllowFallback fast-path already tried it once).
		out := streamFallbackDownload(params.TrackID, params.Quality, params.PreferredProvider, params.TrackName, params.ArtistName, params.ISRC, params.DurationMS, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID)
		if out.encrypted != nil {
			return streamEncryptedJSON(out.encrypted, params.PreferredProvider)
		}
		if out.err != nil {
			// Surface the structured error (errorType/service) so the client can
			// open the right verification flow, not just the raw message.
			return streamFallbackErrorJSON(fmt.Errorf("%v; fallback: %v", err, out.err), out)
		}
		pkg = &streaming.StreamPackage{
			AudioURL: out.fileURL,
			Provider: "fallback",
			Quality:  params.Quality,
		}
	}
	data, _ := json.Marshal(pkg)
	return string(data)
}

// streamFallbackErrorJSON builds the RPC error response for a failed fallback
// download, carrying the structured errorType/service so the client can react
// (e.g. open a Cloudflare verification modal for the provider that needs it).
func streamFallbackErrorJSON(err error, out *streamFallbackOutcome) string {
	mp := map[string]interface{}{"error": err.Error()}
	if out != nil {
		if out.errorType != "" {
			mp["errorType"] = out.errorType
		}
		if out.service != "" {
			mp["service"] = out.service
		}
	}
	data, _ := json.Marshal(mp)
	return string(data)
}

// streamEncryptedInfo carries an encrypted/DRM file that needs client-side
// decryption (e.g. amazon FLAC with a decryption key, when no CLI ffmpeg is
// available on the platform). The file is kept on disk.
type streamEncryptedInfo struct {
	FilePath  string
	Key       string
	OutputExt string
}

// streamEncryptedJSON builds the RPC response telling the client an encrypted
// file is ready and must be decrypted (e.g. via ffmpeg-kit) before playback.
func streamEncryptedJSON(info *streamEncryptedInfo, provider string) string {
	mp := map[string]interface{}{
		"needsDecryption": true,
		"filePath":        info.FilePath,
		"decryptionKey":   info.Key,
		"outputExtension": info.OutputExt,
		"provider":        provider,
	}
	data, _ := json.Marshal(mp)
	return string(data)
}

// streamFallbackOutcome is the result of a fallback download: either a playable
// file URL, or an encrypted file for the client to decrypt, or an error.
type streamFallbackOutcome struct {
	fileURL   string
	encrypted *streamEncryptedInfo
	err       error
	// errorType classifies the failure (e.g. "verification_required") and
	// service names the provider involved, so the client can open the correct
	// Cloudflare verification flow instead of showing a generic error.
	errorType string
	service   string
}

// streamFallbackDownload downloads the audio for [trackID] into the stream
// cache directory using the same pipeline as an explicit download (extension
// download() or native stream URL → file on disk). Returns a playable file://
// URL that media_kit can open on every platform (desktop + Android), or — when
// the only source is an encrypted/DRM file needing ffmpeg that isn't available
// (Android) — the encrypted file so the client can decrypt via ffmpeg-kit.
func streamFallbackDownload(trackID, quality, provider, trackName, artistName, isrc string, durationMs int, spotifyID, deezerID, tidalID, qobuzID string) *streamFallbackOutcome {
	if downloadOrch == nil {
		return &streamFallbackOutcome{err: fmt.Errorf("descarga no disponible")}
	}
	if trackID == "" && trackName == "" && isrc == "" {
		return &streamFallbackOutcome{err: fmt.Errorf("sin identificador de track")}
	}
	outDir := streamCacheDirPath()
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return &streamFallbackOutcome{err: err}
	}
	// Pass the item id but keep the source provider: the orchestrator uses it
	// ONLY on the provider that owns it (so amazon's ASIN isn't fed to deezer
	// etc.), and resolves every other provider via ISRC (then strict search).
	// This is what lets a feed item play back via the same extension that
	// produced it (e.g. amazon) instead of name-searching from scratch.
	res := downloadOrch.Download(download.Request{
		ItemID:     trackID,
		Title:      trackName,
		Artist:     artistName,
		Provider:   provider,
		ISRC:       isrc,
		TrackID:    trackID,
		Quality:    quality,
		OutputDir:  outDir,
		DurationMS: durationMs,
		SpotifyID:  spotifyID,
		DeezerID:   deezerID,
		TidalID:    tidalID,
		QobuzID:    qobuzID,
	})
	// Cache-only downloads must not leak into the download tracker: the Flutter
	// download UI polls getAllDownloadProgress and would otherwise record this
	// track as a real user download (DB row + "downloaded" badge).
	if downloadOrch.Progress() != nil {
		downloadOrch.Progress().Remove(trackID)
	}
	if res == nil || !res.Success || res.FilePath == "" {
		msg := "descarga fallida"
		if res != nil && res.Error != "" {
			msg = res.Error
		}
		out := &streamFallbackOutcome{err: fmt.Errorf("%s", msg)}
		if res != nil {
			out.errorType = res.ErrorType
			out.service = res.Service
		}
		return out
	}
	// A provider handed back an encrypted/DRM file with a key but no CLI ffmpeg
	// to decrypt it here: keep it and let the client decrypt (ffmpeg-kit).
	if res.Encrypted && res.ClientDecrypt && res.DecryptionKey != "" {
		return &streamFallbackOutcome{encrypted: &streamEncryptedInfo{
			FilePath:  res.FilePath,
			Key:       res.DecryptionKey,
			OutputExt: res.OutputExtension,
		}}
	}
	// A provider that only has an encrypted/DRM stream (and no usable decrypt
	// path) would leave a file the player cannot decode. Never serve it as a
	// "playable" fallback — that only caused an endless "Error decoding audio"
	// loop on the device.
	if res.Encrypted {
		_ = os.Remove(res.FilePath)
		return &streamFallbackOutcome{err: fmt.Errorf("%s: stream encriptado no reproducible", res.Provider)}
	}
	// The orchestrator already transformed the file to the user's chosen
	// quality (lossy → mp3 bitrate, lossless kept as-is), so no extra step here.
	evictStreamCache(outDir)
	abs, err := filepath.Abs(res.FilePath)
	if err != nil {
		abs = res.FilePath
	}
	return &streamFallbackOutcome{fileURL: "file://" + filepath.ToSlash(abs)}
}

// streamCacheDirPath returns the directory for stream-fallback audio files.
// Lives inside the user's download dir so it follows the chosen storage
// location, mirroring the normal download folder logic.
func streamCacheDirPath() string {
	base := downloadDir
	if base == "" {
		base = download.GlobalOutputDir()
	}
	if base == "" {
		base = os.TempDir()
	}
	return filepath.Join(base, ".stream_cache")
}

// evictStreamCache bounds the stream cache to the configured MB cap (or the
// plan limit when unset) and to a sane file count, deleting the oldest files
// first so repeated fallback downloads don't fill the disk.
func evictStreamCache(dir string) {
	limitMB := streamCacheMaxMB
	if limitMB <= 0 {
		limitMB = streamCacheLevelLimitMB()
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
	const maxFiles = 60
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

// StreamAudioChunk fetches a byte range of audio directly (mobile/AAR).
func StreamAudioChunk(payload string) string {
	if streamer == nil {
		streamer = streaming.NewStreamer()
	}
	var params struct {
		AudioURL  string `json:"audioURL"`
		OffsetStr string `json:"offset"`
		LengthStr string `json:"length"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	offset, _ := strconv.ParseInt(params.OffsetStr, 10, 64)
	length, _ := strconv.ParseInt(params.LengthStr, 10, 64)
	if length <= 0 {
		length = 256 * 1024 // default 256KB chunk
	}
	data, err := streamer.StreamChunk(params.AudioURL, offset, length)
	if err != nil {
		return jsonError(err)
	}
	encoded := base64.StdEncoding.EncodeToString(data)
	result := map[string]interface{}{
		"data":   encoded,
		"size":   len(data),
		"offset": offset,
	}
	out, _ := json.Marshal(result)
	return string(out)
}
