package download

import (
	"context"
	"errors"
	"sync"
)

// ═══════════════════════════════════════════════════════════════════════
// Download Cancellation Registry — context-based with reference counting
// ═══════════════════════════════════════════════════════════════════════

var (
	// ErrDownloadCancelled is returned when a download is cancelled.
	ErrDownloadCancelled = errors.New("download cancelled")
	// ErrExtensionRequestCancelled is returned when an extension request is cancelled.
	ErrExtensionRequestCancelled = errors.New("extension request cancelled")
)

// cancelEntry tracks a cancellation context and its reference count.
type cancelEntry struct {
	cancel    context.CancelFunc
	refs      int
	cancelled bool
}

// CancelRegistry manages download and extension request cancellation.
type CancelRegistry struct {
	mu              sync.Mutex
	downloadCancels map[string]*cancelEntry
	requestCancels  map[string]*cancelEntry
}

// NewCancelRegistry creates a new cancellation registry.
func NewCancelRegistry() *CancelRegistry {
	return &CancelRegistry{
		downloadCancels: make(map[string]*cancelEntry),
		requestCancels:  make(map[string]*cancelEntry),
	}
}

// InitDownloadCancel registra un contexto de cancelacion para una descarga.
// Devuelve el contexto que se cancela cuando se llama CancelDownload.
func (cr *CancelRegistry) InitDownloadCancel(itemID string) context.Context {
	cr.mu.Lock()
	defer cr.mu.Unlock()

	if entry, ok := cr.downloadCancels[itemID]; ok {
		entry.refs++
		return context.Background() // already has a context
	}

	ctx, cancel := context.WithCancel(context.Background())
	cr.downloadCancels[itemID] = &cancelEntry{cancel: cancel, refs: 1}
	return ctx
}

// IsDownloadCancelled reports whether a download has been cancelled.
func (cr *CancelRegistry) IsDownloadCancelled(itemID string) bool {
	cr.mu.Lock()
	defer cr.mu.Unlock()
	entry, ok := cr.downloadCancels[itemID]
	if !ok {
		return false
	}
	return entry.cancelled
}

// CancelDownload cancels a download and signals all waiters.
func (cr *CancelRegistry) CancelDownload(itemID string) {
	cr.mu.Lock()
	defer cr.mu.Unlock()
	if entry, ok := cr.downloadCancels[itemID]; ok {
		entry.cancelled = true
		entry.cancel()
	}
}

// ClearDownloadCancel removes a download cancellation entry when the
// download completes or is abandoned. If refs > 0, decrements; otherwise deletes.
func (cr *CancelRegistry) ClearDownloadCancel(itemID string) {
	cr.mu.Lock()
	defer cr.mu.Unlock()
	entry, ok := cr.downloadCancels[itemID]
	if !ok {
		return
	}
	entry.refs--
	if entry.refs <= 0 {
		entry.cancel()
		delete(cr.downloadCancels, itemID)
	}
}

// ResetDownloadCancel drops a pre-registered cancellation flag for an item
// with no active download, so a retry does not consume a stale cancel.
func (cr *CancelRegistry) ResetDownloadCancel(itemID string) {
	cr.mu.Lock()
	defer cr.mu.Unlock()
	if entry, ok := cr.downloadCancels[itemID]; ok && entry.refs <= 0 {
		entry.cancelled = false
		delete(cr.downloadCancels, itemID)
	}
}

// InitExtensionRequestCancel registers a cancellation context for an
// extension API request (search, feed, etc.). Supersedes any older request.
