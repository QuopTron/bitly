package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

// RegisterMiscHandlers registers miscellaneous RPC methods.
func RegisterMiscHandlers(reg *rpc.Registry) {
	reg.Register("cleanupConnections", func(params map[string]interface{}) (interface{}, error) {
		// In the old backend this closed idle HTTP connections.
		// The new backend uses per-request HTTP clients that are disposed naturally.
		return "ok", nil
	})

	reg.Register("setNetworkCompatibilityOptions", func(params map[string]interface{}) (interface{}, error) {
		// In the old backend this configured HTTP client options (allow HTTP, insecure TLS).
		// The new backend handles this via the HTTP transport package.
		return "ok", nil
	})

	reg.Register("clearTrackCache", func(params map[string]interface{}) (interface{}, error) {
		// In the old backend this cleared an in-memory LRU track ID cache.
		// The new backend doesn't have this cache.
		return "ok", nil
	})

	reg.Register("getTrackCacheSize", func(params map[string]interface{}) (interface{}, error) {
		// No in-memory cache in new backend.
		return "0", nil
	})

	reg.Register("getTrackCacheSizeBytes", func(params map[string]interface{}) (interface{}, error) {
		return "0", nil
	})

	reg.Register("preWarmTrackCache", func(params map[string]interface{}) (interface{}, error) {
		// In the old backend this pre-warmed the availability cache.
		// The new backend fetches availability on-demand.
		result := map[string]interface{}{
			"success": true,
			"message": "Pre-warming is not needed in the new backend (on-demand fetching)",
		}
		return result, nil
	})
}
