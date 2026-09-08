package download

import (
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Directorio global de descargas sincronizado desde Flutter (setDownloadDirectory).
var (
	downloadDirGlobal string
	outputDirMu       sync.RWMutex
)

// SetGlobalOutputDir guarda el directorio de descargas del usuario.
func SetGlobalOutputDir(dir string) {
	outputDirMu.Lock()
	defer outputDirMu.Unlock()
	downloadDirGlobal = dir
}

// GlobalOutputDir devuelve el directorio global de descargas actual.
func GlobalOutputDir() string {
	outputDirMu.RLock()
	defer outputDirMu.RUnlock()
	return downloadDirGlobal
}

// maxConcurrentDownloads caps how many downloads run at once to avoid
// overwhelming low-end devices. Overridable via SetConcurrency.
const maxConcurrentDownloads = 1

// maxParallelCandidates bounds how many resolved providers are raced in
// parallel for a single download. The warm resolve already surfaced the fastest
// sources first, so beyond this a slow extra candidate just wastes budget.
const maxParallelCandidates = 4

// maxParallelDownloads caps simultaneous in-flight download attempts for ONE
// request (the "second plans" race). Providers that fail fast (429/verification)
// release their slot quickly, so this rarely saturates.
const maxParallelDownloads = 3

// authorityGrace is how long the download race waits, after a last-resort
// (name-search) provider finishes first, for an exact/authoritative companion
// (still in flight) to land the real original before accepting the faster but
// possibly-wrong source. Kept short so a stream is never held up noticeably.
const authorityGrace = 3 * time.Second

// downloadCooldownOp scopes this package's circuit-breaker state to the
// "download" operation bucket. Downloads hitting 429/rate-limits cool the
// provider ONLY for downloads (and stream fallback), never for search/feed —
// so a big download that rate-limits a few providers can't leave the next
// search looking "empty".
const downloadCooldownOp = "download"

// maxFallbackDuration acota cuánto tiempo el respaldo multi-proveedor puede
// seguir iniciando intentos. El canal RPC de Android hace timeout de
// getStreamPackage a los 60s, así que mantenerse muy por debajo deja que el
// orchestrator devuelva un error estructurado (errorType/service) en vez de
// ser matado a mitad de vuelo.
const maxFallbackDuration = 50 * time.Second

// raceResolutionTimeout is how long the preferred (owner) provider is allowed
// to resolve before the playback race hands off to whichever provider was ready
// first. Short enough to keep first-play fast on slow sources (e.g. amazon's
// web search), long enough that the preferred high-quality source usually wins.
const raceResolutionTimeout = 5 * time.Second

// NewOrchestrator creates a download orchestrator with fallback chain.
func NewOrchestrator(reg *provider.Registry) *Orchestrator {
	return &Orchestrator{
		providers:     reg,
		tracker:       NewTracker(),
		active:        make(map[string]bool),
		concurrency:   make(chan struct{}, maxConcurrentDownloads),
		fallbackOrder: construirOrdenFallback(reg, preferredStreamOrder),
	}
}

// SetConcurrency reemplaza el limitador de concurrencia. Debe llamarse sin
// descargas activas (p. ej. en el sync de configuracion antes de iniciar lotes).
func (o *Orchestrator) SetConcurrency(n int) {
	if n < 1 {
		n = 1
	}
	o.mu.Lock()
	o.concurrency = make(chan struct{}, n)
	o.mu.Unlock()
}

// SetDownloadProviderPriority y sanitizarPrioridadProvidersDescarga viven en
// orchestrator_priority.go; lastResortProviders/esProviderUltimoRecurso
// también.
