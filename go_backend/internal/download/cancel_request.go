package download

import (
	"context"
)

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
