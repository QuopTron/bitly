// Package gobackend is the gomobile AAR bridge.
// Each exported function is a direct call from Flutter.
package gobackend

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"runtime/debug"

	"github.com/zarz/bitly/go_backend/internal/bin"
	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
	"github.com/zarz/bitly/go_backend/internal/cache"
	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/extensions"
	core "github.com/zarz/bitly/go_backend/internal/gobackend"
	"github.com/zarz/bitly/go_backend/internal/httpclient"
	"github.com/zarz/bitly/go_backend/internal/library"
	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/playback"
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
)

// Global instances initialized on first use.
var (
	reg              *provider.Registry
	searchEngine     *search.Engine
	downloadOrch     *download.Orchestrator
	rescueSvc        *rescue.Rescuer
	enricher         *rescue.Enricher
	recommendEng     *recommend.Engine
	lyricsClient     *lyrics.Client
	scrobbleClient   *scrobble.Client
	extRegistry      *extensions.Registry
	lib              *library.Library
	binMgr           *bin.Manager
	ytdlpPath        string
	streamer         interface {
		StartServer(int) (string, error)
		StopServer() error
		StreamChunk(string, int64, int64) ([]byte, error)
	}
	playbackTracker    *playback.Tracker
	premiumChecker     *premium.Checker
	sessionMgr         *extensions.SessionManager
	sessionConfigs     map[string]*extensions.SignedSessionConfig
	flutterCallbackID  string
	bundledExts        []bundled_extensions.RegisteredExtension

	// ISRC index for library scanning and fast duplicate detection.
	isrcIndex *cache.ISRCIndex

	// Download staging for atomic writes via .partial files.
	staging *download.StagingManager

	// Cancel registry for context-based download cancellation.
	cancelReg *download.CancelRegistry

	// Download prep cache for repeated preparation of the same track.
	prepCache *download.PrepCache

	// Extension store for remote registry, verification, install/uninstall.
	extStore *extensions.ExtensionStore

	// Cross-extension collection sharing.
	crossShare *extensions.CrossExtensionShare

	// DNS manager for DNS-over-HTTPS resolution.
	dnsMgr *httpclient.DNSManager

	// Runtime state synced from Flutter (config / covers / stream cache)
	downloadDir      string
	userMode         string
	streamCacheMaxMB int
	extSettings      map[string]map[string]string

	// recoveredInitError holds the panic message from InitGlobalState so Flutter
	// can surface root-cause instead of a silent crash.
	recoveredInitError string
)

// =========================================================================
// SYSTEM
// =========================================================================

func Ping() string        { return "pong" }
func GetBuildInfo() string { d, _ := json.Marshal(core.GetBuildInfo()); return string(d) }
func GetPlatform() string  { return core.Platform() }
func IsMobile() bool       { return core.IsMobile() }
func InitBackend() error   { return core.InitBackend() }
func CloseBackend()        { core.CloseBackend() }
func SetFlutterCallback(id string) { flutterCallbackID = id }
func GetCallbackID() string          { return flutterCallbackID }

func InitGlobalState() string {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("[goBackend] InitGlobalState PANIC: %v\n%s", r, debug.Stack())
			recoveredInitError = fmt.Sprintf("init panic: %v", r)
		}
	}()
	recoveredInitError = ""
	// Always initialize — reg must be set even if InitBackend() was called separately.
	reg = provider.NewRegistry()

	// Initialize the binary manager and resolve a data dir for downloaded
	// tool binaries (yt-dlp, ffmpeg) before registering providers.
	binDir := binDataDir()
	binMgr = bin.NewManager(binDir)
	ytdlpPath = binMgr.ResolvedYTDLPPath()

	// Register extension-based providers FIRST (may be overwritten by native below).
	// Best-effort registry: never nil even if the dir is unwritable, so the
	// embedded (-web) extensions always load on every device (Android included).
	extRegistry = extensions.NewRegistryBestEffort(extensionsDir())
	bundledExts = bundled_extensions.LoadAllToRegistry(extRegistry)
	// Names of built-in providers superseded by a bundled extension. We must
	// not register those natives, otherwise the source picker shows duplicates
	// (e.g. qobuz AND qobuz-web, spotify AND spotify-web).
	replacedByExt := map[string]bool{}
	for _, ext := range bundledExts {
		if ext.Enabled {
			ep := provider.NewExtensionProvider(ext.ID, ext.ID, extRegistry.Runtime())
			ep.SetHomeFeedEnabled(ext.HasHomeFeed)
			ep.SetQualityOptions(ext.QualityOptions)
			ep.SetDownloadCapable(ext.IsDownloadProvider)
			reg.Register(ep)
			for _, rp := range ext.Replaces {
				// Keep the native 'spotify' provider registered alongside the
				// 'spotify-web' extension (it exposes a different search/feed
				// surface), so both appear as separate sources.
				if rp == "spotify" {
					continue
				}
				replacedByExt[rp] = true
			}
		}
	}

	// Register native providers AFTER extensions.
	// Some extensions (deezer, soundcloud) have getHomeFeed + download,
	// so we skip their native versions to avoid overwriting.
	nativeRegister := []provider.Provider{
		deezer.NewClient(nil),
		qobuz.NewClient(nil, ""),
		tidal.NewClient(nil, "", ""),
		spotify.NewClient(nil, "", ""),
		youtube.NewClient(ytdlpPath),
		musicbrainz.NewClient(nil, ""),
		apple.NewClient(nil, "", "us"),
		soundcloud.NewClient(nil, ""),
	}
	for _, np := range nativeRegister {
		if replacedByExt[np.Name()] {
			continue
		}
		if reg.Get(np.Name()) == nil {
			reg.Register(np)
		}
		// If extension with same name exists, keep the extension (has getHomeFeed + download)
	}

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
	extSettings = make(map[string]map[string]string)

	// Initialize ISRC index (used for library duplicate detection and fast lookup).
	isrcIndex = cache.NewISRCIndex()

	// Initialize download staging (atomic writes via .partial files).
	staging = download.NewStagingManager()

	// Initialize cancel registry (context-based download cancellation).
	cancelReg = download.NewCancelRegistry()

	// Initialize prep cache (128-entry LRU for repeated download preparation).
	prepCache = download.NewPrepCache()

	// Initialize extension store (remote registry, verification, install/uninstall).
	extStore = extensions.NewExtensionStore(extensionsDir(), extensionsDir())

	// Initialize cross-extension sharing (collection search across extensions).
	crossShare = extensions.NewCrossExtensionShare(extRegistry)

	// Initialize DNS manager (DNS-over-HTTPS with Cloudflare + Google).
	dnsMgr = httpclient.GetDNSManager()

	go func() {
		// Background tool-binary download must never crash the app: a panic
		// here (e.g. nil deref in the network/download path) would abort the
		// whole process during startup. Recover + nil-guard keep it best-effort.
		defer func() {
			if r := recover(); r != nil {
				log.Println("[goBackend] bin ensure recovered:", r)
			}
		}()
		if binMgr == nil {
			return
		}
		binMgr.EnsureYTDLP()
		if ff, err := binMgr.EnsureFFmpeg(); err == nil && ff != nil && ff.Path != "" {
			download.SetFFmpegPath(ff.Path)
		}
	}()

	if !core.IsReady() {
		core.InitBackend()
	}

	allProviders := reg.Names()
	resp := map[string]any{
		"ok":                true,
		"providers":         allProviders,
		"bundled_extensions": len(bundledExts),
	}
	d, _ := json.Marshal(resp)
	return string(d)
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

// extensionsDir resolves a writable directory for extension JS, portable across
// desktop and mobile (Android cwd is "/" and not writable).
func extensionsDir() string {
	if d := os.Getenv("BITLY_EXT_DIR"); d != "" {
		return d
	}
	if d, err := os.UserConfigDir(); err == nil && d != "" {
		return filepath.Join(d, "bitly", "extensions")
	}
	return "extensions"
}

// binDataDir resolves a writable directory for downloaded tool binaries,
// portable across desktop and mobile (Android/iOS).
func binDataDir() string {
	if core.IsMobile() {
		if d := os.Getenv("BITLY_BIN_DIR"); d != "" {
			return d
		}
		// gomobile apps can read the app's files dir via env set by Flutter.
		if d, err := os.UserConfigDir(); err == nil && d != "" {
			return filepath.Join(d, "bitly", "bin")
		}
		return "bitly_bin"
	}
	if d := os.Getenv("BITLY_BIN_DIR"); d != "" {
		return d
	}
	if d, err := os.UserConfigDir(); err == nil && d != "" {
		return filepath.Join(d, "bitly", "bin")
	}
	return "./bin"
}
