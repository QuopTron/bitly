package extensions

import (
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/dop251/goja"
)

// RuntimeConfig defines sandbox limits and permissions.
type RuntimeConfig struct {
	TimeoutMs      int      `json:"timeoutMs"`      // max execution time (ms)
	AllowedDomains []string `json:"allowedDomains"` // HTTP whitelist
	AllowedDirs    []string `json:"allowedDirs"`    // Filesystem whitelist
	EnableFS       bool     `json:"enableFs"`       // allow file operations
	EnableCrypto   bool     `json:"enableCrypto"`   // allow crypto operations
	EnableNetwork  bool     `json:"enableNetwork"`  // allow HTTP requests
	EnableStorage  bool     `json:"enableStorage"`  // allow KV storage
}

// DefaultConfig returns a safe default sandbox config.
func DefaultConfig() RuntimeConfig {
	return RuntimeConfig{
		TimeoutMs:      10000, // 10 seconds
		AllowedDomains: []string{},
		EnableFS:       false,
		EnableCrypto:   true,
		EnableNetwork:  true,
		EnableStorage:  true,
	}
}

// Sandbox wraps a goja runtime with security controls.
type Sandbox struct {
	// lockCh serializes access to the goja VM. The Android bridge runs RPCs on
	// a single thread, but background downloads now execute extension JS in
	// their own goroutine, so a search on the bridge thread can touch the same
	// sandbox while a download is mid-call. goja is not thread-safe, so every
	// CallMethod/HasMethod/Close takes this lock. Different extensions have
	// different sandboxes and never contend. The channel form (instead of a
	// plain sync.Mutex) lets callers bound the wait — see tryLock — so a
	// sandbox stuck in a synchronous JS call can't deadlock later calls.
	lockCh        chan struct{}
	VM            *goja.Runtime
	Config        RuntimeConfig
	Store         *Storage
	ID            string
	DataDir       string
	SignedSession *SignedSessionConfig
	Session       *SignedSessionState
	httpClient    *http.Client
	// vmReady marca que la VM ya está compilada y usable. Es atómico (y no una
	// lectura suelta de VM) porque la compilación puede ocurrir en una goroutine
	// de fondo —el warm-up— mientras el hilo del puente pregunta si la extensión
	// está lista. `mu` serializa la transición con los ajustes encolados: ver
	// markLoadedAndDrainSettings.
	vmReady atomic.Bool
	// settingsMu protege pendingSettings. Es un candado propio y no lockCh
	// porque lockCh también serializa las llamadas JS (y puede estar tomado por
	// una llamada larga) mientras que esto solo protege un mapa de ajustes.
	settingsMu      sync.Mutex
	pendingSettings map[string]string
	// callStartedAt marca el inicio de la llamada JS en curso (ver CallMethod).
	// Las extensiones lo usan vía utils.getResolutionRemainingMs() para no
	// encadenar reintentos cuando ya no queda presupuesto y el RPC del cliente
	// está por cortar. Se escribe bajo el lock del sandbox; lo lee la propia
	// llamada JS (misma goroutine), así que no requiere sincronización aparte.
	callStartedAt time.Time
}
