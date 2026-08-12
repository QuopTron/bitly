package main

import (
	"encoding/json"
	"io"
	"net/http"

	backend "github.com/zarz/bitly/go_backend"
)

// registerExtraRoutes registers playlist, cue, convert, library, file metadata,
// extensions, and Cloudflare session endpoints.
func registerExtraRoutes(mux *http.ServeMux) {
	// ─── PLAYLIST ─────────────────────────────────────────────
	mux.HandleFunc("/playlist/export", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		name := r.URL.Query().Get("name")
		creator := r.URL.Query().Get("creator")
		if name == "" { name = "Playlist" }
		payload, _ := json.Marshal(map[string]string{"tracksJSON": string(body), "name": name, "creator": creator})
		jsonStr(w, backend.ExportPlaylistXSPF(string(payload)))
	})
	mux.HandleFunc("/playlist/parse", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		jsonStr(w, backend.ParsePlaylistXSPF(string(body)))
	})

	// ─── CUE ──────────────────────────────────────────────────
	mux.HandleFunc("/cue/parse", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		jsonStr(w, backend.ParseCUE(string(body)))
	})

	// ─── CONVERT ──────────────────────────────────────────────
	mux.HandleFunc("/convert", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		jsonStr(w, backend.ConvertFile(string(body)))
	})

	// ─── LIBRARY ──────────────────────────────────────────────
	mux.HandleFunc("/library/scan", func(w http.ResponseWriter, r *http.Request) {
		dir := r.URL.Query().Get("dir")
		if dir == "" { http.Error(w, `{"error":"falta el directorio"}`, 400); return }
		jsonStr(w, backend.ScanLibrary(dir))
	})
	mux.HandleFunc("/library/stats", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.GetLibraryStats())
	})

	// ─── FILE METADATA ───────────────────────────────────────
	mux.HandleFunc("/metadata/file", func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Query().Get("path")
		if path == "" { http.Error(w, `{"error":"falta la ruta"}`, 400); return }
		jsonStr(w, backend.ReadFileMetadata(path))
	})
	mux.HandleFunc("/metadata/embed-cover", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" { http.Error(w, `{"error":"usa POST"}`, 400); return }
		var req struct {
			Path string `json:"path"`
			Data []byte `json:"data"`
		}
		body, _ := io.ReadAll(r.Body)
		if err := json.Unmarshal(body, &req); err != nil || req.Path == "" {
			http.Error(w, `{"error":"falta la ruta o los datos"}`, 400); return
		}
		payload, _ := json.Marshal(map[string]interface{}{"path": req.Path, "data": req.Data})
		jsonStr(w, backend.EmbedCover(string(payload)))
	})

	// ─── EXTENSIONS ───────────────────────────────────────────
	mux.HandleFunc("/extensions/list", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.GetInstalledExtensions())
	})
	mux.HandleFunc("/extensions/bundled", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.GetBundledExtensions())
	})
	mux.HandleFunc("/extensions/init", func(w http.ResponseWriter, r *http.Request) {
		dir := r.URL.Query().Get("dir")
		dataDir := r.URL.Query().Get("data")
		if dir == "" { dir = "./extensions" }
		if dataDir == "" { dataDir = "./data" }
		payload, _ := json.Marshal(map[string]string{"extensions_dir": dir, "data_dir": dataDir})
		jsonStr(w, backend.InitExtensionSystem(string(payload)))
	})

	// ─── CLOUDFLARE SESSIONS ──────────────────────────────────
	mux.HandleFunc("/session/auth-url", func(w http.ResponseWriter, r *http.Request) {
		extID := r.URL.Query().Get("ext")
		if extID == "" { http.Error(w, `{"error":"falta ext"}`, 400); return }
		jsonStr(w, backend.GetSessionAuthURL(extID))
	})
	mux.HandleFunc("/session/exchange", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var req struct {
			ExtensionID string `json:"extensionId"`
			GrantCode   string `json:"grantCode"`
		}
		if err := json.Unmarshal(body, &req); err != nil || req.ExtensionID == "" || req.GrantCode == "" {
			http.Error(w, `{"error":"falta extensionId o grantCode"}`, 400); return
		}
		payload, _ := json.Marshal(map[string]string{"extensionID": req.ExtensionID, "grantCode": req.GrantCode})
		jsonStr(w, backend.ExchangeSessionGrant(string(payload)))
	})
	mux.HandleFunc("/session/status", func(w http.ResponseWriter, r *http.Request) {
		extID := r.URL.Query().Get("ext")
		if extID == "" { http.Error(w, `{"error":"falta ext"}`, 400); return }
		jsonStr(w, backend.GetSessionStatus(extID))
	})
	mux.HandleFunc("/session/list", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.ListSessions())
	})
	mux.HandleFunc("/session/revoke", func(w http.ResponseWriter, r *http.Request) {
		extID := r.URL.Query().Get("ext")
		if extID == "" { http.Error(w, `{"error":"falta ext"}`, 400); return }
		jsonStr(w, backend.RevokeSession(extID))
	})
	mux.HandleFunc("/session/refresh", func(w http.ResponseWriter, r *http.Request) {
		extID := r.URL.Query().Get("ext")
		if extID == "" { http.Error(w, `{"error":"falta ext"}`, 400); return }
		jsonStr(w, backend.RefreshSessionToken(extID))
	})
	mux.HandleFunc("/session/store", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var req struct {
			ExtensionID  string `json:"extensionId"`
			Token        string `json:"token"`
			RefreshToken string `json:"refreshToken"`
			ExpiresIn    int    `json:"expiresIn"`
		}
		if err := json.Unmarshal(body, &req); err != nil || req.ExtensionID == "" {
			http.Error(w, `{"error":"falta extensionId"}`, 400); return
		}
		payload, _ := json.Marshal(map[string]interface{}{
			"extensionID": req.ExtensionID, "token": req.Token,
			"refreshToken": req.RefreshToken, "expiresIn": req.ExpiresIn,
		})
		jsonStr(w, backend.StoreSessionToken(string(payload)))
	})
}
