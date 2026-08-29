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
	cancel  context.CancelFunc
	refs    int
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

// globalCancelRegistry is the singleton used by the download pipeline.
var globalCancelRegistry = NewCancelRegistry()

// InitDownloadCancel registers a cancellation context for a download.
// Returns a context that is cancelled when CancelDownload is called.
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
func (cr *CancelRegistry) InitExtensionRequestCancel(requestID string) context.Context {
	cr.mu.Lock()
	defer cr.mu.Unlock()

	// Cancel any existing request with this ID
	if entry, ok := cr.requestCancels[requestID]; ok {
		entry.cancel()
	}

	ctx, cancel := context.WithCancel(context.Background())
	cr.requestCancels[requestID] = &cancelEntry{cancel: cancel, refs: 1}
	return ctx
}

// IsExtensionRequestCancelled reports whether a request has been cancelled.
func (cr *CancelRegistry) IsExtensionRequestCancelled(requestID string) bool {
	cr.mu.Lock()
	defer cr.mu.Unlock()
	entry, ok := cr.requestCancels[requestID]
	if !ok {
		return false
	}
	return entry.cancelled
}

// CancelExtensionRequest cancels an extension request.
func (cr *CancelRegistry) CancelExtensionRequest(requestID string) {
	cr.mu.Lock()
	defer cr.mu.Unlock()
	if entry, ok := cr.requestCancels[requestID]; ok {
		entry.cancelled = true
		entry.cancel()
	}
}

// ClearExtensionRequestCancel removes an extension request entry.
func (cr *CancelRegistry) ClearExtensionRequestCancel(requestID string) {
	cr.mu.Lock()
	defer cr.mu.Unlock()
	if entry, ok := cr.requestCancels[requestID]; ok {
		entry.cancel()
		delete(cr.requestCancels, requestID)
	}
}

// ═══════════════════════════════════════════════════════════════════════
// Global convenience functions
// ═══════════════════════════════════════════════════════════════════════

func initDownloadCancel(itemID string) context.Context {
	return globalCancelRegistry.InitDownloadCancel(itemID)
}

func isDownloadCancelled(itemID string) bool {
	return globalCancelRegistry.IsDownloadCancelled(itemID)
}

func cancelDownload(itemID string) {
	globalCancelRegistry.CancelDownload(itemID)
}

func clearDownloadCancel(itemID string) {
	globalCancelRegistry.ClearDownloadCancel(itemID)
}

func resetDownloadCancel(itemID string) {
	globalCancelRegistry.ResetDownloadCancel(itemID)
}

func initExtensionRequestCancel(requestID string) context.Context {
	return globalCancelRegistry.InitExtensionRequestCancel(requestID)
}

func isExtensionRequestCancelled(requestID string) bool {
	return globalCancelRegistry.IsExtensionRequestCancelled(requestID)
}

func cancelExtensionRequest(requestID string) {
	globalCancelRegistry.CancelExtensionRequest(requestID)
}

func clearExtensionRequestCancel(requestID string) {
	globalCancelRegistry.ClearExtensionRequestCancel(requestID)
}
