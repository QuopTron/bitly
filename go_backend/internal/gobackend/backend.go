// Package gobackend manages the Go middleware lifecycle.
//
// Architecture:
//
//	exports.go → gobackend.InitBackend() → dispatcher → handlers
//	                                                │
//	        ┌───────────────────────────────────────┼───────────────┐
//	        ▼                                       ▼               ▼
//	provider/ (Deezer, Qobuz...)          cache/ (memoria)   download/
package gobackend

import (
	"fmt"
	"log"
	"sync"
)

var (
	globalBackend   *Backend
	globalBackendMu sync.Mutex
)

// Backend holds all global state for the Go middleware.
type Backend struct {
	started bool
}

// InitBackend initializes the Go backend.
// Must be called once at app start.
func InitBackend() error {
	globalBackendMu.Lock()
	defer globalBackendMu.Unlock()

	if globalBackend != nil && globalBackend.started {
		return nil
	}
	if globalBackend == nil {
		globalBackend = &Backend{}
	}
	globalBackend.started = true
	log.Println("[backend] Initialized")
	return nil
}

// CloseBackend cleanly shuts down the backend.
func CloseBackend() {
	globalBackendMu.Lock()
	defer globalBackendMu.Unlock()
	if globalBackend != nil {
		globalBackend.started = false
	}
	globalBackend = nil
	log.Println("[backend] Closed")
}

// IsReady returns true if the backend has been initialized.
func IsReady() bool {
	globalBackendMu.Lock()
	defer globalBackendMu.Unlock()
	return globalBackend != nil && globalBackend.started
}

// requireReady returns an error if the backend is not initialized.
func requireReady() error {
	if !IsReady() {
		return fmt.Errorf("backend not initialized")
	}
	return nil
}
