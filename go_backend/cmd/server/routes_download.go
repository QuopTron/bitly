package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"

	backend "github.com/zarz/bitly/go_backend"
)

// registerDownloadRoutes registers download, streaming, lyrics, and scrobble endpoints.
func registerDownloadRoutes(mux *http.ServeMux) {
	// ─── DOWNLOAD ─────────────────────────────────────────────
	mux.HandleFunc("/download", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		jsonStr(w, backend.DownloadTrack(string(body)))
	})
	mux.HandleFunc("/download/batch", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		jsonStr(w, backend.DownloadBatch(string(body)))
	})
	mux.HandleFunc("/download/extension", func(w http.ResponseWriter, r *http.Request) {
		ext := r.URL.Query().Get("ext")
		trackID := r.URL.Query().Get("trackId")
		quality := r.URL.Query().Get("quality")
		output := r.URL.Query().Get("output")
		if ext == "" || trackID == "" || output == "" {
			http.Error(w, `{"error":"falta ext, trackId o output"}`, 400); return
		}
		if quality == "" { quality = "FLAC" }
		payload, _ := json.Marshal(map[string]string{
			"extProvider": ext, "trackID": trackID, "quality": quality, "outputPath": output,
		})
		jsonStr(w, backend.ExtensionDownload(string(payload)))
	})
	mux.HandleFunc("/download/progress", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.GetDownloadProgress())
	})
	mux.HandleFunc("/download/cancel", func(w http.ResponseWriter, r *http.Request) {
		id := r.URL.Query().Get("id")
		if id == "" { http.Error(w, `{"error":"falta el id"}`, 400); return }
		jsonStr(w, fmt.Sprintf(`{"ok":%t}`, backend.CancelDownload(id)))
	})

	// ─── STREAMING ────────────────────────────────────────────
	mux.HandleFunc("/stream/url", func(w http.ResponseWriter, r *http.Request) {
		p, id := r.URL.Query().Get("provider"), r.URL.Query().Get("trackId")
		quality := r.URL.Query().Get("quality")
		if quality == "" { quality = "FLAC" }
		if p == "" || id == "" { http.Error(w, `{"error":"falta proveedor o trackId"}`, 400); return }
		payload, _ := json.Marshal(map[string]string{"providerName": p, "trackID": id, "quality": quality})
		jsonStr(w, backend.GetStreamURL(string(payload)))
	})
	mux.HandleFunc("/stream/server/start", func(w http.ResponseWriter, r *http.Request) {
		portStr := r.URL.Query().Get("port")
		port := 18765
		if p, err := strconv.Atoi(portStr); err == nil { port = p }
		jsonStr(w, backend.StartStreamingServer(port))
	})
	mux.HandleFunc("/stream/server/stop", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.StopStreamingServer())
	})
	mux.HandleFunc("/stream/chunk", func(w http.ResponseWriter, r *http.Request) {
		url := r.URL.Query().Get("url")
		offset := r.URL.Query().Get("offset")
		length := r.URL.Query().Get("length")
		if url == "" { http.Error(w, `{"error":"falta la URL"}`, 400); return }
		if offset == "" { offset = "0" }
		if length == "" { length = "262144" }
		payload, _ := json.Marshal(map[string]string{"audioURL": url, "offset": offset, "length": length})
		jsonStr(w, backend.StreamAudioChunk(string(payload)))
	})

	// ─── STREAM PACKAGE ───────────────────────────────────────
	mux.HandleFunc("/stream/play", func(w http.ResponseWriter, r *http.Request) {
		provider := r.URL.Query().Get("provider")
		trackID := r.URL.Query().Get("trackId")
		quality := r.URL.Query().Get("quality")
		if quality == "" { quality = "FLAC" }
		fetchLyrics := r.URL.Query().Get("lyrics")
		trackName := r.URL.Query().Get("trackName")
		artistName := r.URL.Query().Get("artistName")
		if trackID == "" { http.Error(w, `{"error":"falta trackId"}`, 400); return }
		payload, _ := json.Marshal(map[string]string{
			"preferredProvider": provider, "trackID": trackID, "quality": quality,
			"fetchLyrics": fetchLyrics, "trackName": trackName, "artistName": artistName,
		})
		jsonStr(w, backend.GetStreamPackage(string(payload)))
	})

	// ─── LYRICS ───────────────────────────────────────────────
	mux.HandleFunc("/lyrics", func(w http.ResponseWriter, r *http.Request) {
		track := r.URL.Query().Get("track")
		artist := r.URL.Query().Get("artist")
		durationStr := r.URL.Query().Get("duration")
		var duration int64
		if d, err := strconv.ParseInt(durationStr, 10, 64); err == nil { duration = d }
		if track == "" || artist == "" { http.Error(w, `{"error":"falta canción o artista"}`, 400); return }
		payload, _ := json.Marshal(map[string]interface{}{
			"trackName": track, "artistName": artist, "durationMs": duration,
		})
		jsonStr(w, backend.FetchLyrics(string(payload)))
	})
	mux.HandleFunc("/genius/token", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" { http.Error(w, `{"error":"usa POST"}`, 400); return }
		body, _ := io.ReadAll(r.Body)
		var req struct { Token string `json:"token"` }
		if err := json.Unmarshal(body, &req); err != nil || req.Token == "" {
			http.Error(w, `{"error":"falta el token"}`, 400); return
		}
		jsonStr(w, backend.SetGeniusToken(req.Token))
	})

	// ─── SCROBBLE ─────────────────────────────────────────────
	mux.HandleFunc("/scrobble/setup", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		jsonStr(w, fmt.Sprintf(`{"ok":%t}`, backend.SetupScrobbling(string(body))))
	})
	mux.HandleFunc("/scrobble/send", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var req struct {
			TrackJSON  string `json:"track"`
			SessionKey string `json:"session"`
		}
		if err := json.Unmarshal(body, &req); err != nil || req.TrackJSON == "" {
			http.Error(w, `{"error":"falta la canción"}`, 400); return
		}
		payload, _ := json.Marshal(map[string]string{"trackJSON": req.TrackJSON, "lastfmSessionKey": req.SessionKey})
		jsonStr(w, backend.ScrobbleTrack(string(payload)))
	})
}
