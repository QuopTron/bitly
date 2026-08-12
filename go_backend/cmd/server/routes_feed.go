package main

import (
	"encoding/json"
	"net/http"
	"strconv"

	backend "github.com/zarz/bitly/go_backend"
)

// registerFeedRoutes registers feed-related endpoints.
func registerFeedRoutes(mux *http.ServeMux) {
	// ─── HOME FEED ───────────────────────────────────────────────
	mux.HandleFunc("/feed/home", func(w http.ResponseWriter, r *http.Request) {
		locale := r.URL.Query().Get("locale")
		if locale == "" {
			locale = "en"
		}
		jsonStr(w, backend.GetHomeFeed(locale))
	})

	// ─── SEARCH (unified) ────────────────────────────────────────
	mux.HandleFunc("/search", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		if q == "" {
			http.Error(w, `{"error":"falta el parámetro q"}`, 400)
			return
		}
		limitStr := r.URL.Query().Get("limit")
		limit := 20
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
			limit = l
		}
		source := r.URL.Query().Get("source")
		searchType := r.URL.Query().Get("type")
		if searchType == "" {
			searchType = "track"
		}
		payload, _ := json.Marshal(map[string]interface{}{
			"query":  q,
			"limit":  limit,
			"source": source,
			"type":   searchType,
		})
		jsonStr(w, backend.Search(string(payload)))
	})
}
