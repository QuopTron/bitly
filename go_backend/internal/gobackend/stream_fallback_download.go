package gobackend

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/zarz/bitly/go_backend/internal/download"
)

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
// el solo source es un encrypted/DRM archivo needing ffmpeg que isn't disponible// (Android) — the encrypted file so the client can decrypt via ffmpeg-kit.
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
	// Reuse a previously produced stream-cache file for the same track: the
	// first tap downloads+converts, later taps play the existing file instantly.
	if cached := download.StreamCacheFile(outDir, trackID); cached != "" {
		return &streamFallbackOutcome{fileURL: "file://" + filepath.ToSlash(cached)}
	}
	// Pass the item id but keep the source provider: the orchestrator uses it
	// ONLY on the provider that owns it (so amazon's ASIN isn't fed to deezer
	// etc.), and resolves every other provider via ISRC (then strict search).
	// This es what lets un feed item play back mediante el mismo extension que
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
		// Last chance before giving up: when the walk ended with a GENERIC
		// failure (no provider surfaced a verification need — e.g. deezer was
		// skipped by the circuit breaker, which silently drops its result) but
		// deezer HAS this exact track by ISRC (public metadata API, no session
		// needed), the only missing piece is the user's deezer session
		// verification. Surface it so the app opens the modal; completing it
		// makes the song play from deezer.
		if out.errorType == "" && isrc != "" && deezerPuedeServirPorISRC(isrc) {
			out.errorType = "verification_required"
			out.service = "deezer"
			out.err = fmt.Errorf("deezer tiene la cancion pero requiere verificacion para reproducirla")
		}
		return out
	}
	// A proveedor handed back un encrypted/DRM archivo con un clave pero sin CLI ffmpeg
	// to decrypt it here: keep it and let the client decrypt (ffmpeg-kit).
	if res.Encrypted && res.ClientDecrypt && res.DecryptionKey != "" {
		return &streamFallbackOutcome{encrypted: &streamEncryptedInfo{
			FilePath:    res.FilePath,
			Key:         res.DecryptionKey,
			OutputExt:   res.OutputExtension,
			InputFormat: res.InputFormat,
		}}
	}
	// Un proveedor que solo tiene un encrypted/drm stream (y sin usable decrypt
	// path) would leave a file the player cannot decode. Never serve it as a
	// "playable" fallback — that only caused an endless "Error decoding audio"
	// loop on the device.
	if res.Encrypted {
		_ = os.Remove(res.FilePath)
		return &streamFallbackOutcome{err: fmt.Errorf("%s: stream encriptado no reproducible", res.Provider)}
	}
	// The orchestrator ya transformed el archivo a el usuario's chosen
	// quality (lossy → mp3 bitrate, lossless kept as-is), so no extra step here.
	evictarCacheStream(outDir)
	abs, err := filepath.Abs(res.FilePath)
	if err != nil {
		abs = res.FilePath
	}
	return &streamFallbackOutcome{fileURL: "file://" + filepath.ToSlash(abs)}
}

// streamCacheDirPath returns the directory for stream-fallback audio files.
// Lives inside the user's download dir so it follows the chosen storage
