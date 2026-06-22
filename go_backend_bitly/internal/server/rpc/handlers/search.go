package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/search"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/providers"
)

var globalSearchService *search.Service

func initSearchService() {
	if globalSearchService != nil {
		return
	}
	registry := core.NewProviderRegistry()
	providers.RegisterAllBuiltin(registry)
	globalSearchService = search.NewService(registry)
}

func RegisterSearchHandlers(reg *rpc.Registry) {
	registerSearchTracks(reg)
	registerSearchAvailability(reg)
}
