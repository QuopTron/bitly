package main

import (
	"encoding/json"
	"net/http"
	"strconv"

	backend "github.com/zarz/bitly/go_backend/internal/gobackend"
)

// registerCoreRoutes registers system, search, and metadata endpoints.
func registerCoreRoutes(mux *http.ServeMux) {
	// ─── SYSTEM ───────────────────────────────────────────────
	mux.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		// Ping() devuelve texto plano (`pong`) pero esta ruta declara
		// application/json: sin comillas el cuerpo no era JSON válido y
		// cualquier cliente que hiciera jsonDecode fallaba.
		jsonStr(w, strconv.Quote(backend.Ping()))
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
	// /red        → peticiones HTTP salientes desde el último reinicio
	// /red?reset=1 → reinicia el acumulado y devuelve el snapshot nuevo
	//
	// Para qué: medir el coste en idas a la red de UNA operación real (un
	// toque de stream, una descarga) — el "antes/después" de las
	// optimizaciones de streaming y descarga. Solo cuenta host, método y
	// número de peticiones.
	mux.HandleFunc("/red", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("reset") == "1" {
			jsonStr(w, backend.RedReiniciar())
			return
		}
		jsonStr(w, backend.RedEstado())
	})

	// ─── SEARCH ───────────────────────────────────────────────
	mux.HandleFunc("/search/tracks", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		if q == "" {
			http.Error(w, `{"error":"falta el parámetro q"}`, 400)
			return
		}
		jsonStr(w, backend.SearchTracks(q))
	})
	mux.HandleFunc("/search/albums", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		if q == "" {
			http.Error(w, `{"error":"falta el parámetro q"}`, 400)
			return
		}
		jsonStr(w, backend.SearchAlbums(q))
	})
	mux.HandleFunc("/search/artists", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		if q == "" {
			http.Error(w, `{"error":"falta el parámetro q"}`, 400)
			return
		}
		jsonStr(w, backend.SearchArtists(q))
	})
	mux.HandleFunc("/search/playlists", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		if q == "" {
			http.Error(w, `{"error":"falta el parámetro q"}`, 400)
			return
		}
		jsonStr(w, backend.SearchPlaylists(q))
	})

	// ─── METADATA ─────────────────────────────────────────────
	mux.HandleFunc("/track", func(w http.ResponseWriter, r *http.Request) {
		p, id := r.URL.Query().Get("provider"), r.URL.Query().Get("id")
		if p == "" || id == "" {
			http.Error(w, `{"error":"falta proveedor o id"}`, 400)
			return
		}
		payload, _ := json.Marshal(map[string]string{"providerName": p, "trackID": id})
		jsonStr(w, backend.GetTrack(string(payload)))
	})
	mux.HandleFunc("/album", func(w http.ResponseWriter, r *http.Request) {
		p, id := r.URL.Query().Get("provider"), r.URL.Query().Get("id")
		if p == "" || id == "" {
			http.Error(w, `{"error":"falta proveedor o id"}`, 400)
			return
		}
		payload, _ := json.Marshal(map[string]string{"providerName": p, "albumID": id})
		jsonStr(w, backend.GetAlbum(string(payload)))
	})
	mux.HandleFunc("/artist", func(w http.ResponseWriter, r *http.Request) {
		p, id := r.URL.Query().Get("provider"), r.URL.Query().Get("id")
		if p == "" || id == "" {
			http.Error(w, `{"error":"falta proveedor o id"}`, 400)
			return
		}
		payload, _ := json.Marshal(map[string]string{"providerName": p, "artistID": id})
		jsonStr(w, backend.GetArtist(string(payload)))
	})
	mux.HandleFunc("/resolve/isrc", func(w http.ResponseWriter, r *http.Request) {
		isrc := r.URL.Query().Get("isrc")
		if isrc == "" {
			http.Error(w, `{"error":"falta el ISRC"}`, 400)
			return
		}
		jsonStr(w, backend.ResolveISRC(isrc))
	})
}
