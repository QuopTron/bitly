// Package gobackend provides the gomobile-bindable API for Android.
//
// This file contains all exported functions that are compiled into the
// Android AAR via `gomobile bind`. Each exported function becomes a static
// method on the generated Java class (gobackend.Gobackend).
//
// Architecture:
//   - InitBackend  initialises the database and the RPC dispatcher.
//   - InvokeRPC    is the single entry point for calling any RPC method.
//   - Convenience  wrappers (SearchYouTubeVideo, …) are provided for
//     operations that are used heavily from the Flutter layer.
package gobackend

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc/handlers"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

// ---------------------------------------------------------------------------
// Global state (single backend instance per process)
// ---------------------------------------------------------------------------

var (
	globalDispatcher   *rpc.Dispatcher
	globalDispatcherMu sync.Mutex
)

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

// InitBackend opens (or creates) the SQLite database at dbPath, creates the
// RPC dispatcher, and registers every handler group.  Call once at app start.
//
// Thread-safe: subsequent calls return nil if already initialised.  If a
// previous call failed, calling again with a fixed dbPath will retry.
func InitBackend(dbPath string) error {
	globalDispatcherMu.Lock()
	defer globalDispatcherMu.Unlock()

	if globalDispatcher != nil {
		return nil // already initialised
	}

	if err := database.Init(dbPath); err != nil {
		return fmt.Errorf("InitBackend: database init: %w", err)
	}

	dispatcher := rpc.NewDispatcher()
	reg := dispatcher.Registry

	handlers.RegisterSystemHandlers(reg)
	handlers.RegisterPremiumHandlers(reg)
	handlers.RegisterMetadataHandlers(reg)
	handlers.RegisterSearchHandlers(reg)
	handlers.RegisterDownloadHandlers(reg)
	handlers.RegisterPlaybackHandlers(reg)
	handlers.RegisterLibraryHandlers(reg)
	handlers.RegisterLyricsHandlers(reg)
	handlers.RegisterVideoHandlers(reg)
	handlers.RegisterScrobblingHandlers(reg)
	handlers.RegisterAvailabilityHandlers(reg)
	handlers.RegisterExtensionHandlers(reg)
	handlers.RegisterV2Handlers(reg)
	handlers.RegisterStatsHandlers(reg)
	handlers.RegisterSecretsHandlers(reg)
	handlers.RegisterNormalizationHandlers(reg)
	handlers.RegisterPlaylistHandlers(reg)
	handlers.RegisterUpdateHandlers(reg)
	handlers.RegisterMiscHandlers(reg)
	handlers.RegisterPostProcessingHandlers(reg)
	handlers.RegisterCueSheetHandlers(reg)
	handlers.RegisterDuplicateHandlers(reg)
	handlers.RegisterAvailabilityDeezerExtra(reg)

	globalDispatcher = dispatcher
	return nil
}

// CloseBackend cleanly shuts down the database and releases resources.
// Safe to call even if InitBackend was never called or failed.
func CloseBackend() {
	globalDispatcherMu.Lock()
	globalDispatcher = nil
	globalDispatcherMu.Unlock()

	if err := database.Close(); err != nil {
		log.Printf("[gobackend] CloseBackend: database close error: %v", err)
	}
}

// ---------------------------------------------------------------------------
// Generic RPC
// ---------------------------------------------------------------------------

// InvokeRPC calls an RPC method with the given JSON-encoded params and
// returns the result as a JSON string (or an error).
//
// Example:
//
//	result, err := gobackend.InvokeRPC("ping", "")
//	result, err := gobackend.InvokeRPC("searchTracks", `{"query":"bohemian rhapsody"}`)
func InvokeRPC(method string, paramsJSON string) (string, error) {
	globalDispatcherMu.Lock()
	d := globalDispatcher
	globalDispatcherMu.Unlock()
	if d == nil {
		return "", fmt.Errorf("InvokeRPC: backend not initialised (call InitBackend first)")
	}

	var params map[string]interface{}
	if paramsJSON != "" {
		if err := json.Unmarshal([]byte(paramsJSON), &params); err != nil {
			return "", fmt.Errorf("InvokeRPC: invalid params JSON: %w", err)
		}
	}

	result, err := d.Registry.Dispatch(method, params)
	if err != nil {
		return "", fmt.Errorf("InvokeRPC: %s: %w", method, err)
	}

	// If the result is already a string (common for JSON-string handlers),
	// return it directly.
	if s, ok := result.(string); ok {
		return s, nil
	}

	// Otherwise marshal to JSON.
	b, err := json.Marshal(result)
	if err != nil {
		return "", fmt.Errorf("InvokeRPC: marshal result: %w", err)
	}
	return string(b), nil
}

// Ping is a convenience wrapper around InvokeRPC("ping", "").
// Returns "pong" on success.
func Ping() (string, error) {
	return InvokeRPC("ping", "")
}

// ---------------------------------------------------------------------------
// Convenience — YouTube
// ---------------------------------------------------------------------------

// SearchYouTubeVideo searches YouTube for a stream URL for the given track
// and artist.  Returns the first available stream URL.
func SearchYouTubeVideo(trackName, artistName string) (string, error) {
	return InvokeRPC("searchYouTubeVideo", fmt.Sprintf(
		`{"track_name":%q,"artist_name":%q}`, trackName, artistName,
	))
}

// DownloadYouTubeVideo downloads a YouTube video to outputPath.
func DownloadYouTubeVideo(trackName, artistName, outputPath string) (string, error) {
	return InvokeRPC("downloadYouTubeVideo", fmt.Sprintf(
		`{"track_name":%q,"artist_name":%q,"output_path":%q}`,
		trackName, artistName, outputPath,
	))
}

// EnsureYtDlp ensures the yt-dlp binary is installed and returns "ok" or
// an error.
func EnsureYtDlp() (string, error) {
	return InvokeRPC("ensureYtDlp", "")
}

// ---------------------------------------------------------------------------
// Convenience — Lyrics
// ---------------------------------------------------------------------------

// FetchLyrics returns lyrics for the given track as a JSON string with
// keys: success, source, sync_type, lines, instrumental.
func FetchLyrics(spotifyID, trackName, artistName string, durationMs int64) (string, error) {
	return InvokeRPC("fetchLyrics", fmt.Sprintf(
		`{"spotify_id":%q,"track_name":%q,"artist_name":%q,"duration_ms":%d}`,
		spotifyID, trackName, artistName, durationMs,
	))
}

// GetLyricsLRC returns the LRC-formatted lyrics for a track.
func GetLyricsLRC(spotifyID, trackName, artistName, filePath string, durationMs int64) (string, error) {
	return InvokeRPC("getLyricsLRC", fmt.Sprintf(
		`{"spotify_id":%q,"track_name":%q,"artist_name":%q,"file_path":%q,"duration_ms":%d}`,
		spotifyID, trackName, artistName, filePath, durationMs,
	))
}

// ---------------------------------------------------------------------------
// Convenience — Metadata
// ---------------------------------------------------------------------------

// ReadFileMetadata reads audio metadata from the given file path and returns
// it as a JSON string.
func ReadFileMetadata(filePath string) (string, error) {
	return InvokeRPC("readFileMetadata", fmt.Sprintf(
		`{"file_path":%q}`, filePath,
	))
}

// SanitizeFilename replaces invalid filename characters with underscores.
func SanitizeFilename(filename string) (string, error) {
	return InvokeRPC("sanitizeFilename", fmt.Sprintf(
		`{"filename":%q}`, filename,
	))
}

// BuildFilename constructs a filename from a template and metadata JSON.
// metadataJSON must be valid JSON.  Returns an error if it is not.
func BuildFilename(template, metadataJSON string) (string, error) {
	if !json.Valid([]byte(metadataJSON)) {
		return "", fmt.Errorf("BuildFilename: metadataJSON is not valid JSON")
	}
	return InvokeRPC("buildFilename", fmt.Sprintf(
		`{"template":%q,"metadata":%s}`, template, metadataJSON,
	))
}

// ExtractCoverToFile extracts cover art from an audio file and writes it
// to the given output path.
func ExtractCoverToFile(audioPath, outputPath string) error {
	_, err := InvokeRPC("extractCoverToFile", fmt.Sprintf(
		`{"audio_path":%q,"output_path":%q}`, audioPath, outputPath,
	))
	return err
}

// ---------------------------------------------------------------------------
// Convenience — Search
// ---------------------------------------------------------------------------

// SearchTracks searches for tracks matching the given query and returns
// results as a JSON string.
func SearchTracks(query string) (string, error) {
	return InvokeRPC("searchTracksJSON", fmt.Sprintf(
		`{"query":%q}`, query,
	))
}

// CheckAvailability checks whether a track is available on streaming
// services and returns a JSON string with availability info.
func CheckAvailability(spotifyID, isrc string) (string, error) {
	return InvokeRPC("checkAvailability", fmt.Sprintf(
		`{"spotify_id":%q,"isrc":%q}`, spotifyID, isrc,
	))
}

// ---------------------------------------------------------------------------
// Convenience — Download
// ---------------------------------------------------------------------------

// DownloadByStrategy initiates a download using the configured extension
// provider strategy.  requestJSON must be a valid DownloadRequest JSON.
func DownloadByStrategy(requestJSON string) (string, error) {
	return InvokeRPC("downloadByStrategy", fmt.Sprintf(
		`{"request":%s}`, requestJSON,
	))
}

// GetDownloadProgress returns the current download progress as a JSON string.
func GetDownloadProgress() (string, error) {
	return InvokeRPC("getDownloadProgress", "")
}

// CancelDownload cancels a running download identified by itemID.
func CancelDownload(itemID string) (string, error) {
	return InvokeRPC("cancelDownload", fmt.Sprintf(
		`{"item_id":%q}`, itemID,
	))
}

// ---------------------------------------------------------------------------
// Convenience — Premium
// ---------------------------------------------------------------------------

// VerificarPremium checks if the given user has an active premium
// subscription.  Returns a JSON map with key "valido".
func VerificarPremium(isPremium int, premiumUntil int64) (string, error) {
	return InvokeRPC("verificarPremium", fmt.Sprintf(
		`{"is_premium":%d,"premium_until":%d}`, isPremium, premiumUntil,
	))
}

// ValidarCodigoPremium validates a premium activation code.
func ValidarCodigoPremium(code string) (string, error) {
	return InvokeRPC("validarCodigoPremium", fmt.Sprintf(
		`{"codigo":%q}`, code,
	))
}

// ---------------------------------------------------------------------------
// Convenience — Playback
// ---------------------------------------------------------------------------

// PlaybackGetState returns the current playback state as a JSON string.
func PlaybackGetState() (string, error) {
	return InvokeRPC("playbackGetState", "")
}

// PlaybackPause pauses playback.
func PlaybackPause() (string, error) {
	return InvokeRPC("playbackPause", "")
}

// PlaybackResume resumes playback.
func PlaybackResume() (string, error) {
	return InvokeRPC("playbackResume", "")
}

// PlaybackNext skips to the next track.
func PlaybackNext() (string, error) {
	return InvokeRPC("playbackNext", "")
}

// PlaybackPrevious returns to the previous track.
func PlaybackPrevious() (string, error) {
	return InvokeRPC("playbackPrevious", "")
}

// PlaybackStop stops playback.
func PlaybackStop() (string, error) {
	return InvokeRPC("playbackStop", "")
}

// PlaybackSeek seeks to the given position in milliseconds.
func PlaybackSeek(positionMs int) (string, error) {
	return InvokeRPC("playbackSeek", fmt.Sprintf(
		`{"position_ms":%d}`, positionMs,
	))
}

// PlaybackSetQueue sets the playback queue from a JSON tracks array.
func PlaybackSetQueue(tracksJSON string) (string, error) {
	return InvokeRPC("playbackSetQueue", fmt.Sprintf(
		`{"tracks":%s}`, tracksJSON,
	))
}

// PlaybackAddToQueue appends tracks to the playback queue.
func PlaybackAddToQueue(tracksJSON string) (string, error) {
	return InvokeRPC("playbackAddToQueue", fmt.Sprintf(
		`{"tracks":%s}`, tracksJSON,
	))
}

// PlaybackGetQueue returns the current playback queue as a JSON string.
func PlaybackGetQueue() (string, error) {
	return InvokeRPC("playbackGetQueue", "")
}

// PlaybackClearQueue clears the playback queue.
func PlaybackClearQueue() (string, error) {
	return InvokeRPC("playbackClearQueue", "")
}

// PlaybackSetShuffle enables or disables shuffle mode (1 = on, 0 = off).
func PlaybackSetShuffle(shuffle int) (string, error) {
	return InvokeRPC("playbackSetShuffle", fmt.Sprintf(
		`{"shuffle":%d}`, shuffle,
	))
}

// PlaybackSetRepeat sets repeat mode ("off", "one", "all").
func PlaybackSetRepeat(mode string) (string, error) {
	return InvokeRPC("playbackSetRepeat", fmt.Sprintf(
		`{"mode":%q}`, mode,
	))
}

// ---------------------------------------------------------------------------
// Convenience — Scrobbling
// ---------------------------------------------------------------------------

// SetupScrobbling saves the scrobbling configuration (Last.fm / ListenBrainz).
// configJSON should contain the full configuration as a JSON object.
func SetupScrobbling(configJSON string) (string, error) {
	return InvokeRPC("setupScrobbling", fmt.Sprintf(
		`{"config":%s}`, configJSON,
	))
}

// GetScrobblingConfig returns the current scrobbling configuration as JSON.
func GetScrobblingConfig() (string, error) {
	return InvokeRPC("getScrobblingConfig", "")
}

// ScrobbleNowPlaying sends a "now playing" notification to all enabled
// scrobbling services.  trackJSON should be a TrackInfo JSON object.
func ScrobbleNowPlaying(trackJSON string) (string, error) {
	return InvokeRPC("scrobbleNowPlaying", fmt.Sprintf(
		`{"track":%s}`, trackJSON,
	))
}

// ScrobbleTrack sends a final scrobble for a completed track to all enabled
// scrobbling services.  trackJSON should be a TrackInfo JSON object.
func ScrobbleTrack(trackJSON string) (string, error) {
	return InvokeRPC("scrobbleTrack", fmt.Sprintf(
		`{"track":%s}`, trackJSON,
	))
}

// ---------------------------------------------------------------------------
// Convenience — Extensions
// ---------------------------------------------------------------------------

// InitExtensionSystem initialises the extension system.
func InitExtensionSystem(extensionsDir, dataDir string) (string, error) {
	return InvokeRPC("initExtensionSystem", fmt.Sprintf(
		`{"extensions_dir":%q,"data_dir":%q}`, extensionsDir, dataDir,
	))
}

// GetInstalledExtensions returns a JSON list of installed extensions.
func GetInstalledExtensions() (string, error) {
	return InvokeRPC("getInstalledExtensions", "")
}

// SetProviderPriority sets the download provider priority order.
func SetProviderPriority(priorityJSON string) (string, error) {
	return InvokeRPC("setProviderPriority", fmt.Sprintf(
		`{"priority":%s}`, priorityJSON,
	))
}

// GetProviderPriority returns the current provider priority order as JSON.
func GetProviderPriority() (string, error) {
	return InvokeRPC("getProviderPriority", "")
}
