package core

import (
	"context"
	"errors"
	"sync"
)

var ErrExtensionRequestCancelled = errors.New("extension request cancelled")

var (
	extensionRequestCancelMu  sync.Mutex
	extensionRequestCancelMap = make(map[string]*cancelEntry)
)

func InitExtensionRequestCancel(requestID string) context.Context {
	if requestID == "" {
		return context.Background()
	}

	extensionRequestCancelMu.Lock()
	defer extensionRequestCancelMu.Unlock()

	if entry, ok := extensionRequestCancelMap[requestID]; ok {
		if entry.ctx == nil {
			ctx, cancel := context.WithCancel(context.Background())
			entry.ctx = ctx
			entry.cancel = cancel
			if entry.canceled && entry.cancel != nil {
				entry.cancel()
			}
		}
		entry.refs++
		return entry.ctx
	}

	ctx, cancel := context.WithCancel(context.Background())
	extensionRequestCancelMap[requestID] = &cancelEntry{
		ctx:      ctx,
		cancel:   cancel,
		canceled: false,
		refs:     1,
	}
	return ctx
}

func CancelExtensionRequest(requestID string) {
	if requestID == "" {
		return
	}

	extensionRequestCancelMu.Lock()
	if entry, ok := extensionRequestCancelMap[requestID]; ok {
		entry.canceled = true
		if entry.cancel != nil {
			entry.cancel()
		}
	} else {
		extensionRequestCancelMap[requestID] = &cancelEntry{canceled: true}
	}
	extensionRequestCancelMu.Unlock()
}

func IsExtensionRequestCancelled(requestID string) bool {
	if requestID == "" {
		return false
	}

	extensionRequestCancelMu.Lock()
	entry, ok := extensionRequestCancelMap[requestID]
	canceled := ok && entry.canceled
	extensionRequestCancelMu.Unlock()
	return canceled
}

func ClearExtensionRequestCancel(requestID string) {
	if requestID == "" {
		return
	}

	extensionRequestCancelMu.Lock()
	if entry, ok := extensionRequestCancelMap[requestID]; ok {
		entry.refs--
		if entry.refs <= 0 {
			delete(extensionRequestCancelMap, requestID)
		}
	}
	extensionRequestCancelMu.Unlock()
}
