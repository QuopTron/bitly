package core

import (
	"context"
	"errors"
	"sync"

	"github.com/zarz/bitly/go_backend_bitly/internal/download/progress"
)

var ErrDownloadCancelled = errors.New("download cancelled")

type cancelEntry struct {
	ctx      context.Context
	cancel   context.CancelFunc
	canceled bool
	refs     int
}

var (
	cancelMu  sync.Mutex
	cancelMap = make(map[string]*cancelEntry)
)

func InitDownloadCancel(itemID string) context.Context {
	if itemID == "" {
		return context.Background()
	}

	cancelMu.Lock()
	defer cancelMu.Unlock()

	if entry, ok := cancelMap[itemID]; ok {
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
	cancelMap[itemID] = &cancelEntry{
		ctx:      ctx,
		cancel:   cancel,
		canceled: false,
		refs:     1,
	}
	return ctx
}

func CancelDownload(itemID string) {
	if itemID == "" {
		return
	}

	cancelMu.Lock()
	entry, ok := cancelMap[itemID]
	if ok {
		entry.canceled = true
		if entry.cancel != nil {
			entry.cancel()
		}
	} else {
		cancelMap[itemID] = &cancelEntry{canceled: true}
	}
	cancelMu.Unlock()

	progress.RemoveItemProgress(itemID)
}

func IsDownloadCancelled(itemID string) bool {
	if itemID == "" {
		return false
	}

	cancelMu.Lock()
	entry, ok := cancelMap[itemID]
	canceled := ok && entry.canceled
	cancelMu.Unlock()
	return canceled
}

func ClearDownloadCancel(itemID string) {
	if itemID == "" {
		return
	}

	cancelMu.Lock()
	if entry, ok := cancelMap[itemID]; ok {
		entry.refs--
		if entry.refs <= 0 {
			delete(cancelMap, itemID)
		}
	}
	cancelMu.Unlock()
}
