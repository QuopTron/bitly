// Package gobackend is the gomobile AAR bridge.
// Each exported function is a direct call from Flutter.
package gobackend

import (
	"encoding/base64"
	"encoding/json"
	"strconv"

	"github.com/zarz/bitly/go_backend/internal/audio"
	"github.com/zarz/bitly/go_backend/internal/bin"
	"github.com/zarz/bitly/go_backend/internal/convert"
	"github.com/zarz/bitly/go_backend/internal/cue"
	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/extensions"
	core "github.com/zarz/bitly/go_backend/internal/gobackend"
	"github.com/zarz/bitly/go_backend/internal/library"
	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/playlist"
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
)

// Global instances initialized on first use.
var (
	reg             *provider.Registry
	searchEngine    *search.Engine
	downloadOrch    *download.Orchestrator
	rescueSvc       *rescue.Rescuer
	enricher        *rescue.Enricher
	recommendEng    *recommend.Engine
	lyricsClient    *lyrics.Client
	scrobbleClient  *scrobble.Client
	extRegistry     *extensions.Registry
	lib             *library.Library
	binMgr          *bin.Manager
	streamer        *streaming.Streamer

	// Flutter callback state
	flutterCallbackID string
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
	// Initialize provider registry — ALL 10 providers
	reg = provider.NewRegistry()
	reg.Register(deezer.NewClient(nil))
	reg.Register(qobuz.NewClient(nil, ""))
	reg.Register(tidal.NewClient(nil, "", ""))
	reg.Register(spotify.NewClient(nil, "", ""))
	reg.Register(youtube.NewClient(""))
	reg.Register(musicbrainz.NewClient(nil, ""))
	reg.Register(apple.NewClient(nil, "", "us"))
	reg.Register(soundcloud.NewClient(nil, ""))
	// Initialize modules
	searchEngine = search.New(reg, search.DefaultConfig())
	downloadOrch = download.NewOrchestrator(reg)
	rescueSvc = rescue.New(reg)
	enricher = rescue.NewEnricher(reg)
	recommendEng = recommend.New(reg)
	lyricsClient = lyrics.NewClient()
	lib = library.New()
	
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
	return `{"ok":true,"providers":["deezer","qobuz","tidal","spotify","youtube","musicbrainz","apple","soundcloud"]}`
}

// =========================================================================
// SEARCH
// =========================================================================

func SearchTracks(query string) string {
	if searchEngine == nil {
		return `{"error":"not initialized"}`
	}
	results, err := searchEngine.SearchTracks(query, 20)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(results)
	return string(data)
}

func SearchAlbums(query string) string {
	if reg == nil {
		return `{"error":"not initialized"}`
	}
	var all []provider.AlbumResult
	for _, p := range reg.All() {
		albums, err := p.SearchAlbums(query, 5)
		if err == nil && albums != nil {
			all = append(all, albums...)
		}
	}
	data, _ := json.Marshal(all)
	return string(data)
}

func SearchArtists(query string) string {
	if reg == nil {
		return `{"error":"not initialized"}`
	}
	var all []provider.ArtistResult
	for _, p := range reg.All() {
		artists, err := p.SearchArtists(query, 5)
		if err == nil && artists != nil {
			all = append(all, artists...)
		}
	}
	data, _ := json.Marshal(all)
	return string(data)
}

// =========================================================================
// METADATA
// =========================================================================

func GetTrack(providerName, trackID string) string {
	if reg == nil {
		return `{"error":"not initialized"}`
	}
	p := reg.Get(providerName)
	if p == nil {
		return jsonErrorStr("provider not found")
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
		return jsonErrorStr("provider not found")
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
		return jsonErrorStr("provider not found")
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
		return `{"error":"not initialized"}`
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

// =========================================================================
// STREAMING
// =========================================================================

func GetStreamURL(providerName, trackID, quality string) string {
	p := reg.Get(providerName)
	if p == nil {
		return jsonErrorStr("provider not found")
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

// StreamAudioChunk fetches a byte range of audio directly (mobile/AAR).
// audioURL: the direct audio URL from GetStreamURL
// offset: byte offset (0 for beginning)
// length: number of bytes to fetch (0 for all)
// Returns base64-encoded audio data.
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

func FetchLyrics(trackName, artistName string, durationMs int64) string {
	if lyricsClient == nil {
		return `{"error":"not initialized"}`
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

// =========================================================================
// LIBRARY
// =========================================================================

func ScanLibrary(directory string) string {
	if lib == nil {
		return `{"error":"not initialized"}`
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
		return `{"error":"not initialized"}`
	}
	result := rescueSvc.RescueByISRC(isrc, trackName, artistName, quality)
	data, _ := json.Marshal(result)
	return string(data)
}

func RescueBatch(tracksJSON string) string {
	if rescueSvc == nil {
		return `{"error":"not initialized"}`
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
		return `{"error":"not initialized"}`
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
		return `{"error":"not initialized"}`
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
		return `{"error":"not initialized"}`
	}
	results, err := recommendEng.SimilarArtists(artistName, limit)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(results)
	return string(data)
}

// =========================================================================
// BATCH DOWNLOAD
// =========================================================================

func DownloadBatch(tracksJSON string) string {
	if downloadOrch == nil {
		return `{"error":"not initialized"}`
	}
	var reqs []download.Request
	if err := json.Unmarshal([]byte(tracksJSON), &reqs); err != nil {
		return jsonError(err)
	}
	results := downloadOrch.DownloadBatch(reqs)
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

// ExportPlaylistXSPF creates an XSPF XML playlist from a JSON array of tracks.
// tracksJSON: JSON array of {title, artist, album, durationMs, isrc, coverUrl, provider, trackId, location}
// name: playlist title
// creator: playlist author
// Returns JSON with the XSPF XML string (properly escaped).
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

// ParsePlaylistXSPF parses an XSPF XML string into a JSON playlist.
// xspfContent: the XSPF XML string
// Returns JSON with the parsed playlist.
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

// =========================================================================
// HELPERS
// =========================================================================

func jsonError(err error) string {
	return `{"error":"` + err.Error() + `"}`
}

func jsonErrorStr(msg string) string {
	return `{"error":"` + msg + `"}`
}
