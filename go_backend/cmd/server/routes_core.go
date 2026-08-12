package main

import (
	"encoding/json"
	"net/http"

	backend "github.com/zarz/bitly/go_backend"
)

// registerCoreRoutes registers system, search, and metadata endpoints.
func registerCoreRoutes(mux *http.ServeMux) {
	// ─── SYSTEM ───────────────────────────────────────────────
	mux.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.Ping())
	})
	mux.HandleFunc("/info", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.GetBuildInfo())
	})
	mux.HandleFunc("/platform", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, `{"platform":"`+backend.GetPlatform()+`"}`)
	})
	mux.HandleFunc("/init", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.InitGlobalState())
	})

	// ─── SEARCH ───────────────────────────────────────────────
	mux.HandleFunc("/search/tracks", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		if q == "" { http.Error(w, `{"error":"falta el parámetro q"}`, 400); return }
		jsonStr(w, backend.SearchTracks(q))
	})
	mux.HandleFunc("/search/albums", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		if q == "" { http.Error(w, `{"error":"falta el parámetro q"}`, 400); return }
		jsonStr(w, backend.SearchAlbums(q))
	})
	mux.HandleFunc("/search/artists", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		if q == "" { http.Error(w, `{"error":"falta el parámetro q"}`, 400); return }
		jsonStr(w, backend.SearchArtists(q))
	})
	mux.HandleFunc("/search/playlists", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		if q == "" { http.Error(w, `{"error":"falta el parámetro q"}`, 400); return }
		jsonStr(w, backend.SearchPlaylists(q))
	})

	// ─── METADATA ─────────────────────────────────────────────
	mux.HandleFunc("/track", func(w http.ResponseWriter, r *http.Request) {
		p, id := r.URL.Query().Get("provider"), r.URL.Query().Get("id")
		if p == "" || id == "" { http.Error(w, `{"error":"falta proveedor o id"}`, 400); return }
		payload, _ := json.Marshal(map[string]string{"providerName": p, "trackID": id})
		jsonStr(w, backend.GetTrack(string(payload)))
	})
	mux.HandleFunc("/album", func(w http.ResponseWriter, r *http.Request) {
		p, id := r.URL.Query().Get("provider"), r.URL.Query().Get("id")
		if p == "" || id == "" { http.Error(w, `{"error":"falta proveedor o id"}`, 400); return }
		payload, _ := json.Marshal(map[string]string{"providerName": p, "albumID": id})
		jsonStr(w, backend.GetAlbum(string(payload)))
	})
	mux.HandleFunc("/artist", func(w http.ResponseWriter, r *http.Request) {
		p, id := r.URL.Query().Get("provider"), r.URL.Query().Get("id")
		if p == "" || id == "" { http.Error(w, `{"error":"falta proveedor o id"}`, 400); return }
		payload, _ := json.Marshal(map[string]string{"providerName": p, "artistID": id})
		jsonStr(w, backend.GetArtist(string(payload)))
	})
	mux.HandleFunc("/resolve/isrc", func(w http.ResponseWriter, r *http.Request) {
		isrc := r.URL.Query().Get("isrc")
		if isrc == "" { http.Error(w, `{"error":"falta el ISRC"}`, 400); return }
		jsonStr(w, backend.ResolveISRC(isrc))
	})
}
