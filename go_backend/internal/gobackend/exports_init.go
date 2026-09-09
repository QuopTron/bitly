package gobackend

import (
	"encoding/json"
	"log"
	"runtime/debug"

	"github.com/zarz/bitly/go_backend/internal/bin"
	core "github.com/zarz/bitly/go_backend/internal/core"
	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/extensions"
	"github.com/zarz/bitly/go_backend/internal/library"
	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/playback"
	"github.com/zarz/bitly/go_backend/internal/premium"
	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/recommend"
	"github.com/zarz/bitly/go_backend/internal/rescue"
	"github.com/zarz/bitly/go_backend/internal/search"
)

// InitGlobalState wires up every service the RPC surface uses: providers
// (extensions + natives), search engine, download orchestrator, rescue,
// lyrics, playback stats, premium, sessions and the auxiliary managers
// (staging, cancel registry, prep cache, extension store, DNS). The actual
// provider registration lives in initProviders; everything else is built
// here in dependency order.
func InitGlobalState() string {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("[goBackend] InitGlobalState PANIC: %v\n%s", r, debug.Stack())
		}
	}()
	// Política de recursos del runtime (límite blando de RAM + GOMAXPROCS
	// acotado): el GC recolecta antes de agotar la RAM del dispositivo y la
	// CPU no se satura contra el UI de Flutter.
	core.AjustarRuntimeMemoria()

	// Always initialize — reg must be set even if InitBackend() was called separately.
	reg = provider.NewRegistry()

	// Initialize the binary manager and resolve a data dir for downloaded
	// tool binaries (yt-dlp, ffmpeg) before registering providers.
	binDir := dirDatosBin()
	binMgr = bin.NewManager(binDir)
	ytdlpPath = binMgr.ResolvedYTDLPPath()

	// Registra extension-based proveedores FIRST (puede ser overwritten por native abajo).
	bundledExts = inicializarProviders(reg)

	searchEngine = search.New(reg, search.DefaultConfig())
	downloadOrch = download.NewOrchestrator(reg)
	rescueSvc = rescue.New(reg)
	enricher = rescue.NewEnricher(reg)
	recommendEng = recommend.New(reg)
	lyricsClient = lyrics.NewClient()
	// Registra los proveedores de letras de extensiones (contrato lyrics_provider
	// de SpotiFLAC: export fetchLyrics) al FINAL de la cadena de respaldo — los
	// integrados (lrclib/genius) responden los casos comunes rápido; solo se
	// consulta una extensión cuando fallan, así los sidecars de letras en lote
	// nunca pagan una búsqueda extra de red por canción que lrclib ya tiene.
	// Cada extensión corre en su propio bucket de cooldown "lyrics", aislado
	// de búsqueda/descarga.
	wireExtensionLyricsProviders(lyricsClient, reg)
	lib = library.New()
	playbackTracker = playback.NewTracker(200)
	premiumChecker = premium.NewChecker(nil)
	sessionMgr = extensions.NewSessionManager()
	sessionConfigs = make(map[string]*extensions.SignedSessionConfig)
	extSettings = make(map[string]map[string]string)

	// Initialize download staging (atomic writes via .partial files).
	staging = download.NewStagingManager()

	// Initialize cancel registry (context-based download cancellation).
	cancelReg = download.NewCancelRegistry()

	// Capturar el manager en una local ANTES del goroutine: el goroutine corre
	// en segundo plano y puede seguir vivo cuando otro test/llamada vuelva a
	// ejecutar InitGlobalState (que reescribe el global binMgr). Leer el global
	// desde el goroutine tras esa reescritura es un data race que `go test
	// -race` detecta (lectura en exports_init.go vs escritura en la llamada
	// siguiente) — con la copia local el goroutine queda aislado del global.
	bm := binMgr
	go func() {
		// Background tool-binary download must never crash the app: a panic
		// here (e.g. nil deref in the network/download path) would abort the
		// whole process during startup. Recover + nil-guard keep it best-effort.
		defer func() {
			if r := recover(); r != nil {
				log.Println("[goBackend] bin ensure recovered:", r)
			}
		}()
		if bm == nil {
			return
		}
		bm.EnsureYTDLP()
		if ff, err := bm.EnsureFFmpeg(); err == nil && ff != nil && ff.Path != "" {
			download.SetFFmpegPath(ff.Path)
		}
	}()

	if !core.IsReady() {
		core.InitBackend()
	}

	// Re-apply any settings stored by an earlier push (extension sandboxes are
	// all present now that LoadAllToRegistry finished). Without this, a
	// credential push that raced extension loading is silently dropped and the
	// extension keeps running anonymous (e.g. YouTube OAuth never reaching the
	// ytmusic extension -> every InnerTube call 403s).
	replicarAjustesExtensiones()

	allProviders := reg.Names()
	resp := map[string]any{
		"ok":                 true,
		"providers":          allProviders,
		"bundled_extensions": len(bundledExts),
	}
	d, _ := json.Marshal(resp)
	return string(d)
}
