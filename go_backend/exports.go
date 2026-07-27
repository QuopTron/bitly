// Package gobackend is the gomobile AAR bridge.
// Each exported function is a direct call from Flutter.
package gobackend

import (
	"encoding/base64"
	"encoding/json"
	"strconv"
	"time"

	"github.com/zarz/bitly/go_backend/internal/audio"
	"github.com/zarz/bitly/go_backend/internal/bin"
	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
	"github.com/zarz/bitly/go_backend/internal/convert"
	"github.com/zarz/bitly/go_backend/internal/cue"
	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/extensions"
	core "github.com/zarz/bitly/go_backend/internal/gobackend"
	"github.com/zarz/bitly/go_backend/internal/library"
	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/playback"
	"github.com/zarz/bitly/go_backend/internal/playlist"
	"github.com/zarz/bitly/go_backend/internal/premium"
	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/apple"
	"github.com/zarz/bitly/go_backend/internal/provider/deezer"
	"github.com/zarz/bitly/go_backend/internal/provider/musicbrainz"
	"github.com/zarz/bitly/go_backend/internal/provider/qobuz"
	"github.com/zarz/bitly/go_backend/internal/provider/soundcloud"
	"github.com/zarz/bitly/go_backend/internal/provider/spotify"
	"github.com/zarz/bitly/go_backend/internal/provider/tidal"
	"github.com/zarz/bitly/go_backend/internal/provider/youtube"
	"github.com/zarz/bitly/go_backend/internal/recommend"
	"github.com/zarz/bitly/go_backend/internal/rescue"
	"github.com/zarz/bitly/go_backend/internal/scrobble"
	"github.com/zarz/bitly/go_backend/internal/search"
	"github.com/zarz/bitly/go_backend/internal/streaming"
)	// Global instances initialized on first use.
var (
	reg             *provider.Registry
	searchEngine    *search.Engine
	downloadOrch    *download.Orchestrator
	rescueSvc       *rescue.Rescuer
	enricher        *rescue.Enricher
	recommendEng    *recommend.Engine
	lyricsClient    *lyrics.Client
	scrobbleClient  *scrobble.Client
	extRegistry      *extensions.Registry
	lib              *library.Library
	binMgr           *bin.Manager
	streamer         *streaming.Streamer
	playbackTracker  *playback.Tracker
	premiumChecker   *premium.Checker
	sessionMgr       *extensions.SessionManager
	sessionConfigs   map[string]*extensions.SignedSessionConfig

	// Flutter callback state
	flutterCallbackID string

	// Bundled extensions loaded at init
	bundledExts []bundled_extensions.RegisteredExtension
)

// =========================================================================
// SYSTEM
// =========================================================================

func InitBackend() error { return core.InitBackend() }
func CloseBackend()      { core.CloseBackend() }

// =========================================================================
// CALLBACK — Flutter → Go communication for user data queries
// =========================================================================

// SetFlutterCallback stores a callback ID that Go can use to invoke
// Flutter functions (e.g., get user library, download history, preferences).
// Flutter should call this with the name of a registered Dart function.
func SetFlutterCallback(callbackID string) {
	flutterCallbackID = callbackID
}

// GetCallbackID returns the registered callback ID for Flutter.
func GetCallbackID() string { return flutterCallbackID }

func Ping() string                { return "pong" }
func GetBuildInfo() string         { data, _ := json.Marshal(core.GetBuildInfo()); return string(data) }
func GetPlatform() string          { return core.Platform() }
func IsMobile() bool               { return core.IsMobile() }

func InitGlobalState() string {
	if core.IsReady() {
		return `{"ok":true}`
	}
	// Initialize provider registry — ALL 8 native providers
	reg = provider.NewRegistry()
	reg.Register(deezer.NewClient(nil))
	reg.Register(qobuz.NewClient(nil, ""))
	reg.Register(tidal.NewClient(nil, "", ""))
	reg.Register(spotify.NewClient(nil, "", ""))
	reg.Register(youtube.NewClient(""))
	reg.Register(musicbrainz.NewClient(nil, ""))
	reg.Register(apple.NewClient(nil, "", "us"))
	reg.Register(soundcloud.NewClient(nil, ""))

	// Initialize extension registry and load bundled extensions
	extRegistry, _ = extensions.NewRegistry(".")
	bundledExts = bundled_extensions.LoadAllToRegistry(extRegistry)

	// Register JS extensions as providers in the search engine
	for _, ext := range bundledExts {
		if ext.Enabled {
			extProvider := provider.NewExtensionProvider(ext.ID, ext.ID, extRegistry.Runtime())
			reg.Register(extProvider)
		}
	}

	// Initialize modules
	searchEngine = search.New(reg, search.DefaultConfig())
	downloadOrch = download.NewOrchestrator(reg)
	rescueSvc = rescue.New(reg)
	enricher = rescue.NewEnricher(reg)
	recommendEng = recommend.New(reg)
	lyricsClient = lyrics.NewClient()
	lib = library.New()
	playbackTracker = playback.NewTracker(200)
	premiumChecker = premium.NewChecker(nil)
	sessionMgr = extensions.NewSessionManager()
	sessionConfigs = make(map[string]*extensions.SignedSessionConfig)

	// Initialize binary manager (yt-dlp, FFmpeg)
	binMgr = bin.NewManager("./bin")
	go func() {
		if b, err := binMgr.EnsureYTDLP(); err == nil {
			_ = b
		}
		if b, err := binMgr.EnsureFFmpeg(); err == nil {
			_ = b
		}
	}()

	core.InitBackend()

	// Build response
	allProviders := reg.Names()
	resp := map[string]interface{}{
		"ok":                 true,
		"providers":          allProviders,
		"bundled_extensions": len(bundledExts),
	}
	data, _ := json.Marshal(resp)
	return string(data)
}

// =========================================================================
// SEARCH
// =========================================================================

func SearchTracks(query string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	// Search each provider individually and return as a map[provider]results
	type namedTracks struct {
		Provider string               `json:"provider"`
		Tracks   []provider.TrackResult `json:"tracks"`
	}
	var results []namedTracks
	for _, p := range reg.All() {
		tracks, err := p.SearchTracks(query, 10)
		if err == nil && len(tracks) > 0 {
			results = append(results, namedTracks{
				Provider: p.Name(),
				Tracks:   tracks,
			})
		}
	}
	data, _ := json.Marshal(results)
	return string(data)
}

func searchByProvider[T any](query string, limit int, fn func(provider.Provider, string, int) ([]T, error)) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	type namedResults struct {
		Provider string `json:"provider"`
		Results  []T    `json:"results"`
	}
	var results []namedResults
	for _, p := range reg.All() {
		res, err := fn(p, query, limit)
		if err == nil && len(res) > 0 {
			results = append(results, namedResults{
				Provider: p.Name(),
				Results:  res,
			})
		}
	}
	data, _ := json.Marshal(results)
	return string(data)
}

func SearchAlbums(query string) string {
	return searchByProvider(query, 5, func(p provider.Provider, q string, l int) ([]provider.AlbumResult, error) {
		return p.SearchAlbums(q, l)
	})
}

func SearchPlaylists(query string) string {
	return searchByProvider(query, 5, func(p provider.Provider, q string, l int) ([]provider.PlaylistResult, error) {
		return p.SearchPlaylists(q, l)
	})
}

func SearchArtists(query string) string {
	return searchByProvider(query, 5, func(p provider.Provider, q string, l int) ([]provider.ArtistResult, error) {
		return p.SearchArtists(q, l)
	})
}

// =========================================================================
// METADATA
// =========================================================================

func GetTrack(providerName, trackID string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	p := reg.Get(providerName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	track, err := p.GetTrack(trackID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(track)
	return string(data)
}

func GetAlbum(providerName, albumID string) string {
	p := reg.Get(providerName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	album, err := p.GetAlbum(albumID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(album)
	return string(data)
}

func GetArtist(providerName, artistID string) string {
	p := reg.Get(providerName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	artist, err := p.GetArtist(artistID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(artist)
	return string(data)
}

func ResolveISRC(isrc string) string {
	if searchEngine == nil {
		return `{"error":"no inicializado"}`
	}
	results, err := searchEngine.SearchTracks("isrc:\""+isrc+"\"", 5)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(results)
	return string(data)
}

// =========================================================================
// DOWNLOAD
// =========================================================================

func DownloadTrack(requestJSON string) string {
	if premiumChecker != nil {
		if err := premiumChecker.CheckDownloadAllowed(); err != nil {
			return jsonError(err)
		}
	}
	var req download.Request
	if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
		return jsonError(err)
	}
	result := downloadOrch.Download(req)
	data, _ := json.Marshal(result)
	return string(data)
}

func GetDownloadProgress() string {
	if downloadOrch == nil {
		return `[]`
	}
	data, _ := json.Marshal(downloadOrch.Progress().GetAll())
	return string(data)
}

func CancelDownload(itemID string) bool {
	if downloadOrch == nil {
		return false
	}
	downloadOrch.Progress().Remove(itemID)
	return true
}

func DownloadBatch(tracksJSON string) string {
	if premiumChecker != nil {
		if err := premiumChecker.CheckDownloadAllowed(); err != nil {
			return jsonError(err)
		}
	}
	if downloadOrch == nil {
		return `{"error":"no inicializado"}`
	}
	var reqs []download.Request
	if err := json.Unmarshal([]byte(tracksJSON), &reqs); err != nil {
		return jsonError(err)
	}
	results := downloadOrch.DownloadBatch(reqs)
	data, _ := json.Marshal(results)
	return string(data)
}

// ExtensionDownload triggers a full JS extension download pipeline.
// Extensions like Amazon, Pandora, Deezer handle their own streaming,
// decryption (e.g., Blowfish), chunked writing, and file management.
// Parameters:
//   extProvider: extension provider name (e.g., "amazon", "deezer")
//   trackID: track ID from search result (without provider: prefix)
//   quality: "FLAC", "MP3", "best", etc.
//   outputPath: where to save the final file
// Returns JSON with {success, filePath, title, artist, album, error}
func ExtensionDownload(extProvider, trackID, quality, outputPath string) string {
	if premiumChecker != nil {
		if err := premiumChecker.CheckDownloadAllowed(); err != nil {
			return jsonError(err)
		}
	}
	p := reg.Get(extProvider)
	if p == nil {
		return jsonErrorStr("extensión no encontrada")
	}
	ep, ok := p.(*provider.ExtensionProvider)
	if !ok {
		return jsonErrorStr("no es una extensión válida")
	}

	// Use a unique progress ID to avoid collisions with orchestrator downloads
	progressID := "ext:" + extProvider + ":" + trackID

	// Track progress via the download orchestrator
	downloadOrch.Progress().Add(progressID, trackID, extProvider)

	result := ep.Download(trackID, quality, outputPath, func(percent int) {
		downloadOrch.Progress().Update(progressID, download.StatusDownloading, float64(percent)/100.0)
	})

	if result.Success {
		downloadOrch.Progress().SetOutputPath(progressID, result.FilePath)
	} else {
		downloadOrch.Progress().SetError(progressID, result.Error)
	}

	data, _ := json.Marshal(result)
	return string(data)
}

// =========================================================================
// STREAMING
// =========================================================================

func GetStreamURL(providerName, trackID, quality string) string {
	p := reg.Get(providerName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	url, err := p.GetStreamURL(trackID, quality)
	if err != nil {
		return jsonError(err)
	}
	return `{"url":"` + url + `"}`
}

var (
	streamingServerAddr string
)

// StartStreamingServer starts an HTTP proxy for audio streaming (desktop).
// Returns the server URL (e.g. "http://localhost:8765").
// Flutter should connect its media player to this address.
func StartStreamingServer(port int) string {
	if streamer == nil {
		streamer = streaming.NewStreamer()
	}
	addr, err := streamer.StartServer(port)
	if err != nil {
		return jsonError(err)
	}
	streamingServerAddr = addr
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
	streamingServerAddr = ""
	return `{"ok":true}`
}

// GetStreamPackage returns a complete stream package: audio URL + metadata + lyrics + cover.
// Hace fallback entre providers si el especificado no tiene stream.
// Parameters:
//   preferredProvider: provider name ("deezer", "qobuz", etc.) or "" for auto
//   trackID: track ID from search
//   quality: "FLAC", "MP3", "lossless", "hi-res", etc.
//   fetchLyrics: "true" or "false"
//   trackName: used for search fallback (optional)
//   artistName: used for search fallback (optional)
func GetStreamPackage(preferredProvider, trackID, quality, fetchLyrics, trackName, artistName string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	fetchL := fetchLyrics == "true" || fetchLyrics == "1"
	pkg, err := streaming.GetStreamPackage(reg, lyricsClient, preferredProvider, trackID, quality, fetchL, trackName, artistName)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(pkg)
	return string(data)
}

// StreamAudioChunk fetches a byte range of audio directly (mobile/AAR).
func StreamAudioChunk(audioURL, offsetStr, lengthStr string) string {
	if streamer == nil {
		streamer = streaming.NewStreamer()
	}

	offset, _ := strconv.ParseInt(offsetStr, 10, 64)
	length, _ := strconv.ParseInt(lengthStr, 10, 64)
	if length <= 0 {
		length = 256 * 1024 // default 256KB chunk
	}

	data, err := streamer.StreamChunk(audioURL, offset, length)
	if err != nil {
		return jsonError(err)
	}

	// Return as base64 for AAR bridge
	encoded := base64.StdEncoding.EncodeToString(data)
	result := map[string]interface{}{
		"data":   encoded,
		"size":   len(data),
		"offset": offset,
	}
	out, _ := json.Marshal(result)
	return string(out)
}

// =========================================================================
// LYRICS
// =========================================================================

// SetGeniusToken configures the Genius access token for lyrics search.
// Call after InitGlobalState with the token from Flutter settings.
func SetGeniusToken(token string) string {
	if lyricsClient == nil {
		return `{"error":"no inicializado"}`
	}
	lyricsClient.SetGeniusToken(token)
	return `{"ok":true}`
}

func FetchLyrics(trackName, artistName string, durationMs int64) string {
	if lyricsClient == nil {
		return `{"error":"no inicializado"}`
	}
	lyrics, err := lyricsClient.GetLyrics(trackName, artistName, int(durationMs))
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(lyrics)
	return string(data)
}

// =========================================================================
// EXTENSIONS
// =========================================================================

// SetSessionConfig stores the Cloudflare signed session configuration for an extension.
// Flutter should call this after loading the extension's manifest to configure its
// Cloudflare auth endpoints (bootstrap, exchange, refresh URLs).
// configJSON: JSON with baseUrl, callbackUrl, endpoints, etc.
func SetSessionConfig(extensionID, configJSON string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	var cfg extensions.SignedSessionConfig
	if err := json.Unmarshal([]byte(configJSON), &cfg); err != nil {
		return jsonError(err)
	}
	if sessionConfigs == nil {
		sessionConfigs = make(map[string]*extensions.SignedSessionConfig)
	}
	sessionConfigs[extensionID] = &cfg
	return `{"ok":true}`
}

// getSessionConfig returns the stored config for an extension, or nil.
func getSessionConfig(extensionID string) *extensions.SignedSessionConfig {
	if sessionConfigs == nil {
		return nil
	}
	return sessionConfigs[extensionID]
}

// GetSessionAuthURL returns a URL for Cloudflare challenge in a WebView.
// The URL comes from the extension's SignedSessionConfig (set via SetSessionConfig).
// extensionID: the extension name (e.g., "deezer", "qobuz")
func GetSessionAuthURL(extensionID string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	cfg := getSessionConfig(extensionID)
	if cfg == nil {
		return jsonErrorStr("sesión no configurada para: " + extensionID + " — llama SetSessionConfig primero")
	}
	result, err := sessionMgr.GetAuthURL(extensionID, cfg)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(result)
	return string(data)
}

// ExchangeSessionGrant exchanges a Cloudflare grant code for a session token.
// extensionID: the extension name
// grantCode: the code obtained from Cloudflare callback redirect
func ExchangeSessionGrant(extensionID, grantCode string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	cfg := getSessionConfig(extensionID)
	if cfg == nil {
		return jsonErrorStr("sesión no configurada para: " + extensionID)
	}
	state, err := sessionMgr.ExchangeGrant(extensionID, cfg, grantCode)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(state)
	return string(data)
}

// GetSessionStatus returns the current Cloudflare session status for an extension.
func GetSessionStatus(extensionID string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	status := sessionMgr.GetSessionStatus(extensionID)
	data, _ := json.Marshal(status)
	return string(data)
}

// ListSessions returns all active Cloudflare sessions.
func ListSessions() string {
	if sessionMgr == nil {
		return `[]`
	}
	sessions := sessionMgr.ListActiveSessions()
	data, _ := json.Marshal(sessions)
	return string(data)
}

// RevokeSession revokes a Cloudflare session for an extension.
func RevokeSession(extensionID string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	sessionMgr.RevokeSession(extensionID)
	return `{"ok":true}`
}

// RefreshSessionToken manually refreshes a Cloudflare session token.
func RefreshSessionToken(extensionID string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	cfg := getSessionConfig(extensionID)
	if cfg == nil {
		return jsonErrorStr("sesión no configurada para: " + extensionID)
	}
	state, err := sessionMgr.RefreshSession(extensionID, cfg)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(state)
	return string(data)
}

// StoreSessionToken manually restores a session token (from Flutter storage).
func StoreSessionToken(extensionID, token, refreshToken string, expiresIn int) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	sessionMgr.StoreSessionToken(extensionID, token, refreshToken, expiresIn)
	return `{"ok":true}`
}

func InitExtensionSystem(extensionsDir, dataDir string) string {
	reg, err := extensions.NewRegistry(extensionsDir)
	if err != nil {
		return jsonError(err)
	}
	extRegistry = reg
	// Run all enabled extensions in sandbox
	cfg := extensions.DefaultConfig()
	for _, ext := range reg.List() {
		if ext.Enabled {
			if _, err := reg.Runtime().RunScript(&ext, cfg, dataDir); err != nil {
				_ = err // silently skip failed extensions
			}
		}
	}
	data, _ := json.Marshal(reg.List())
	return string(data)
}

func GetInstalledExtensions() string {
	if extRegistry == nil {
		return `[]`
	}
	data, _ := json.Marshal(extRegistry.List())
	return string(data)
}

// GetBundledExtensions returns the list of bundled (embedded) extensions.
func GetBundledExtensions() string {
	if len(bundledExts) == 0 {
		return `[]`
	}
	data, _ := json.Marshal(bundledExts)
	return string(data)
}

// =========================================================================
// SCROBBLING
// =========================================================================

func SetupScrobbling(configJSON string) bool {
	var cfg struct {
		LastFMKey    string `json:"lastfmKey"`
		LastFMSecret string `json:"lastfmSecret"`
		LBToken      string `json:"listenBrainzToken"`
	}
	if err := json.Unmarshal([]byte(configJSON), &cfg); err != nil {
		return false
	}
	scrobbleClient = scrobble.NewClient(cfg.LastFMKey, cfg.LastFMSecret, cfg.LBToken)
	return true
}

// ScrobbleTrack submits a playback scrobble to all configured services.
// trackJSON: JSON object with {trackName, artistName, albumName, durationMs, timestamp}
func ScrobbleTrack(trackJSON, lastfmSessionKey string) string {
	if scrobbleClient == nil {
		return `{"error":"scrobbling no configurado"}`
	}
	var track scrobble.Track
	if err := json.Unmarshal([]byte(trackJSON), &track); err != nil {
		return jsonError(err)
	}
	if track.Timestamp == 0 {
		track.Timestamp = time.Now().Unix()
	}

	var errors []string
	if err := scrobbleClient.ScrobbleLastFM(track, lastfmSessionKey); err != nil {
		errors = append(errors, "lastfm:"+err.Error())
	}
	if err := scrobbleClient.ScrobbleListenBrainz(track); err != nil {
		errors = append(errors, "lb:"+err.Error())
	}

	if len(errors) > 0 {
		resp := map[string]interface{}{"ok": false, "errors": errors}
		data, _ := json.Marshal(resp)
		return string(data)
	}
	return `{"ok":true}`
}

// =========================================================================
// PLAYBACK — Go manages queue, history, now-playing
// =========================================================================

// ReportNowPlaying tells Go what track is currently playing.
func ReportNowPlaying(trackJSON string) string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	var track playback.TrackInfo
	if err := json.Unmarshal([]byte(trackJSON), &track); err != nil {
		return jsonError(err)
	}
	playbackTracker.SetNowPlaying(&track)
	return `{"ok":true}`
}

// GetNowPlaying returns the current track, or null.
func GetNowPlaying() string {
	if playbackTracker == nil {
		return `{}`
	}
	track := playbackTracker.NowPlaying()
	if track == nil {
		return `{}`
	}
	data, _ := json.Marshal(track)
	return string(data)
}

// MarkPlayed records a track as fully played.
func MarkPlayed(trackJSON string, durationSeconds int) string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	var track playback.TrackInfo
	if err := json.Unmarshal([]byte(trackJSON), &track); err != nil {
		return jsonError(err)
	}
	playbackTracker.MarkPlayed(&track, durationSeconds)
	return `{"ok":true}`
}

// GetPlayHistory returns recent plays (newest first).
func GetPlayHistory(limit int) string {
	if playbackTracker == nil {
		return `[]`
	}
	history := playbackTracker.GetHistory(limit)
	if history == nil {
		return `[]`
	}
	data, _ := json.Marshal(history)
	return string(data)
}

// GetPlayQueue returns the current playback queue.
func GetPlayQueue() string {
	if playbackTracker == nil {
		return `[]`
	}
	queue := playbackTracker.Queue()
	data, _ := json.Marshal(queue)
	return string(data)
}

// AddToQueue adds a track to the playback queue.
func AddToQueue(trackJSON, addedBy string) string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	var track playback.TrackInfo
	if err := json.Unmarshal([]byte(trackJSON), &track); err != nil {
		return jsonError(err)
	}
	playbackTracker.AddToQueue(&track, addedBy)
	return `{"ok":true}`
}

// RemoveFromQueue removes a track from queue by position.
func RemoveFromQueue(position int) string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	ok := playbackTracker.RemoveFromQueue(position)
	if !ok {
		return `{"error":"posición inválida"}`
	}
	return `{"ok":true}`
}

// ReorderQueue moves a track in the queue.
func ReorderQueue(oldPos, newPos int) string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	ok := playbackTracker.ReorderQueue(oldPos, newPos)
	if !ok {
		return `{"error":"posición inválida"}`
	}
	return `{"ok":true}`
}

// ClearQueue empties the playback queue.
func ClearQueue() string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	playbackTracker.ClearQueue()
	return `{"ok":true}`
}

// GetPlaybackStats returns playback statistics.
func GetPlaybackStats() string {
	if playbackTracker == nil {
		return `{}`
	}
	data, _ := json.Marshal(playbackTracker.Stats())
	return string(data)
}

// GetRecommendationsFromHistory returns recommended tracks based on listening history.
func GetRecommendationsFromHistory(limit int) string {
	if playbackTracker == nil {
		return `[]`
	}
	recs := playbackTracker.GetRecommendations(limit)
	data, _ := json.Marshal(recs)
	return string(data)
}

// =========================================================================
// PREMIUM — License validation, download blocking for free users
// =========================================================================

// ValidatePremiumCode validates a code and activates premium if valid.
func ValidatePremiumCode(code string) string {
	if premiumChecker == nil {
		return `{"error":"no inicializado"}`
	}
	if err := premiumChecker.ValidateCode(code); err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(premiumChecker.Status())
	return string(data)
}

// SetPremiumStatus manually sets premium status (restore from Flutter storage).
func SetPremiumStatus(isPremium bool, tier string) string {
	if premiumChecker == nil {
		return `{"error":"no inicializado"}`
	}
	premiumChecker.SetPremium(isPremium, tier)
	return `{"ok":true}`
}

// GetPremiumStatus returns the current premium state.
func GetPremiumStatus() string {
	if premiumChecker == nil {
		return `{"isPremium":false,"tier":"free"}`
	}
	data, _ := json.Marshal(premiumChecker.Status())
	return string(data)
}

// CheckDownloadAllowed returns ok if downloads are allowed, error if blocked.
func CheckDownloadAllowed() string {
	if premiumChecker == nil {
		return `{"error":"no inicializado"}`
	}
	if err := premiumChecker.CheckDownloadAllowed(); err != nil {
		return jsonError(err)
	}
	return `{"ok":true}`
}

// =========================================================================
// LIBRARY
// =========================================================================

func ScanLibrary(directory string) string {
	if lib == nil {
		return `{"error":"no inicializado"}`
	}
	entries, err := lib.Scan(directory)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(entries)
	return string(data)
}

func GetLibraryStats() string {
	if lib == nil {
		return `{}`
	}
	data, _ := json.Marshal(lib.GetStats())
	return string(data)
}

// =========================================================================
// RESCUE
// =========================================================================

func RescueTrack(isrc, trackName, artistName, quality string) string {
	if rescueSvc == nil {
		return `{"error":"no inicializado"}`
	}
	result := rescueSvc.RescueByISRC(isrc, trackName, artistName, quality)
	data, _ := json.Marshal(result)
	return string(data)
}

func RescueBatch(tracksJSON string) string {
	if rescueSvc == nil {
		return `{"error":"no inicializado"}`
	}
	var reqs []rescue.RescueRequest
	if err := json.Unmarshal([]byte(tracksJSON), &reqs); err != nil {
		return jsonError(err)
	}
	results := rescueSvc.RescueBatch(reqs)
	data, _ := json.Marshal(results)
	return string(data)
}

func EnrichMetadata(isrc string) string {
	if enricher == nil {
		return `{"error":"no inicializado"}`
	}
	result, err := enricher.EnrichFromISRC(isrc)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(result)
	return string(data)
}

// =========================================================================
// RECOMMENDATIONS
// =========================================================================

func GetSimilarTracks(trackTitle, artistName string, limit int) string {
	if recommendEng == nil {
		return `{"error":"no inicializado"}`
	}
	results, err := recommendEng.SimilarTracks(trackTitle, artistName, limit)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(results)
	return string(data)
}

func GetSimilarArtists(artistName string, limit int) string {
	if recommendEng == nil {
		return `{"error":"no inicializado"}`
	}
	results, err := recommendEng.SimilarArtists(artistName, limit)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(results)
	return string(data)
}

// =========================================================================
// CONVERSION
// =========================================================================

func ConvertFile(requestJSON string) string {
	var req struct {
		convert.Config
		InputPath string `json:"inputPath"`
	}
	if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
		return jsonError(err)
	}
	result, err := convert.Convert(req.Config, req.InputPath)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(result)
	return string(data)
}

// =========================================================================
// PLAYLIST
// =========================================================================

func ExportPlaylistXSPF(tracksJSON, name, creator string) string {
	var tracks []playlist.PlaylistTrack
	if err := json.Unmarshal([]byte(tracksJSON), &tracks); err != nil {
		return jsonError(err)
	}
	pl := playlist.New(name, creator, tracks)
	xmlStr, err := pl.ExportXML()
	if err != nil {
		return jsonError(err)
	}
	result := map[string]string{"xspf": xmlStr}
	data, _ := json.Marshal(result)
	return string(data)
}

func ParsePlaylistXSPF(xspfContent string) string {
	x, err := playlist.Unmarshal(xspfContent)
	if err != nil {
		return jsonError(err)
	}
	pl := playlist.FromXSPF(x)
	data, _ := json.Marshal(pl)
	return string(data)
}

// =========================================================================
// CUE
// =========================================================================

func ParseCUE(cueContent string) string {
	result, err := cue.Parse(cueContent)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(result)
	return string(data)
}

func ReadFileMetadata(filePath string) string {
	meta, err := audio.ReadFileMetadata(filePath)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(meta)
	return string(data)
}

// EmbedCover writes cover art data into an audio file.
// filePath: path to audio file (FLAC, MP3, M4A)
// coverData: raw image bytes (JPEG or PNG)
func EmbedCover(filePath string, coverData []byte) string {
	if err := audio.WriteCover(filePath, coverData); err != nil {
		return jsonError(err)
	}
	return `{"ok":true}`
}

// =========================================================================
// HELPERS
// =========================================================================

func jsonError(err error) string {
	return `{"error":"` + err.Error() + `"}`
}

func jsonErrorStr(msg string) string {
	return `{"error":"` + msg + `"}`
}
