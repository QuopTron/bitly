package extensions

import (
	"net/http"

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
		TimeoutMs:      10000,            // 10 seconds
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
}
