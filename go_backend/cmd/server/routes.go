package main

import "net/http"

// registerAllRoutes registers all HTTP endpoints on the given mux.
func registerAllRoutes(mux *http.ServeMux) {
	registerCoreRoutes(mux)
	registerDownloadRoutes(mux)
	registerPlaybackRoutes(mux)
	registerFeedRoutes(mux)
	registerExtraRoutes(mux)
	registerRPCRoute(mux)
	registerCoverRoute(mux)
}
