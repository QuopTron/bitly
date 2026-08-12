package main

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"

	backend "github.com/zarz/bitly/go_backend"
)

// registerPlaybackRoutes registers premium, playback, queue, rescue, and similar endpoints.
func registerPlaybackRoutes(mux *http.ServeMux) {
	// ─── PREMIUM ──────────────────────────────────────────────
	mux.HandleFunc("/premium/status", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.GetPremiumStatus())
	})
	mux.HandleFunc("/premium/validate", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var req struct { Code string `json:"code"` }
		if err := json.Unmarshal(body, &req); err != nil || req.Code == "" {
			http.Error(w, `{"error":"falta el código"}`, 400); return
		}
		jsonStr(w, backend.ValidatePremiumCode(req.Code))
	})
	mux.HandleFunc("/premium/set", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var req struct {
			IsPremium bool   `json:"isPremium"`
			Tier      string `json:"tier"`
		}
		if err := json.Unmarshal(body, &req); err != nil {
			http.Error(w, `{"error":"cuerpo inválido"}`, 400); return
		}
		payload, _ := json.Marshal(map[string]interface{}{"isPremium": req.IsPremium, "tier": req.Tier})
		jsonStr(w, backend.SetPremiumStatus(string(payload)))
	})
	mux.HandleFunc("/premium/check-download", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.CheckDownloadAllowed())
	})

	// ─── PLAYBACK ─────────────────────────────────────────────
	mux.HandleFunc("/playback/now-playing", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "POST" {
			body, _ := io.ReadAll(r.Body)
			jsonStr(w, backend.ReportNowPlaying(string(body)))
		} else {
			jsonStr(w, backend.GetNowPlaying())
		}
	})
	mux.HandleFunc("/playback/mark-played", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		durationStr := r.URL.Query().Get("duration")
		duration, _ := strconv.Atoi(durationStr)
		payload, _ := json.Marshal(map[string]interface{}{"trackJSON": string(body), "durationSeconds": duration})
		jsonStr(w, backend.MarkPlayed(string(payload)))
	})
	mux.HandleFunc("/playback/history", func(w http.ResponseWriter, r *http.Request) {
		limitStr := r.URL.Query().Get("limit")
		limit := 20
		if l, err := strconv.Atoi(limitStr); err == nil { limit = l }
		jsonStr(w, backend.GetPlayHistory(limit))
	})

	// ─── QUEUE ────────────────────────────────────────────────
	mux.HandleFunc("/playback/queue", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case "GET":
			jsonStr(w, backend.GetPlayQueue())
		case "POST":
			body, _ := io.ReadAll(r.Body)
			addedBy := r.URL.Query().Get("addedBy")
			if addedBy == "" { addedBy = "user" }
			payload, _ := json.Marshal(map[string]string{"trackJSON": string(body), "addedBy": addedBy})
			jsonStr(w, backend.AddToQueue(string(payload)))
		case "DELETE":
			posStr := r.URL.Query().Get("position")
			if pos, err := strconv.Atoi(posStr); err == nil {
				jsonStr(w, backend.RemoveFromQueue(pos))
			} else {
				jsonStr(w, backend.ClearQueue())
			}
		case "PUT":
			oldStr := r.URL.Query().Get("old")
			newStr := r.URL.Query().Get("new")
			old, err1 := strconv.Atoi(oldStr)
			newP, err2 := strconv.Atoi(newStr)
			if err1 == nil && err2 == nil {
				payload, _ := json.Marshal(map[string]int{"oldPos": old, "newPos": newP})
				jsonStr(w, backend.ReorderQueue(string(payload)))
			} else {
				http.Error(w, `{"error":"faltan old/new"}`, 400)
			}
		}
	})
	mux.HandleFunc("/playback/stats", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.GetPlaybackStats())
	})
	mux.HandleFunc("/playback/recommendations", func(w http.ResponseWriter, r *http.Request) {
		limitStr := r.URL.Query().Get("limit")
		limit := 10
		if l, err := strconv.Atoi(limitStr); err == nil { limit = l }
		jsonStr(w, backend.GetRecommendationsFromHistory(limit))
	})

	// ─── RESCUE ───────────────────────────────────────────────
	mux.HandleFunc("/rescue", func(w http.ResponseWriter, r *http.Request) {
		isrc := r.URL.Query().Get("isrc")
		track := r.URL.Query().Get("track")
		artist := r.URL.Query().Get("artist")
		quality := r.URL.Query().Get("quality")
		if quality == "" { quality = "FLAC" }
		if isrc == "" { http.Error(w, `{"error":"falta el ISRC"}`, 400); return }
		payload, _ := json.Marshal(map[string]string{"isrc": isrc, "trackName": track, "artistName": artist, "quality": quality})
		jsonStr(w, backend.RescueTrack(string(payload)))
	})
	mux.HandleFunc("/rescue/batch", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		jsonStr(w, backend.RescueBatch(string(body)))
	})
	mux.HandleFunc("/rescue/enrich", func(w http.ResponseWriter, r *http.Request) {
		isrc := r.URL.Query().Get("isrc")
		if isrc == "" { http.Error(w, `{"error":"falta el ISRC"}`, 400); return }
		jsonStr(w, backend.EnrichMetadata(isrc))
	})

	// ─── SIMILAR ──────────────────────────────────────────────
	mux.HandleFunc("/similar/tracks", func(w http.ResponseWriter, r *http.Request) {
		track := r.URL.Query().Get("track")
		artist := r.URL.Query().Get("artist")
		limitStr := r.URL.Query().Get("limit")
		limit := 10
		if l, err := strconv.Atoi(limitStr); err == nil { limit = l }
		if track == "" { http.Error(w, `{"error":"falta la canción"}`, 400); return }
		payload, _ := json.Marshal(map[string]interface{}{"trackTitle": track, "artistName": artist, "limit": limit})
		jsonStr(w, backend.GetSimilarTracks(string(payload)))
	})
	mux.HandleFunc("/similar/artists", func(w http.ResponseWriter, r *http.Request) {
		artist := r.URL.Query().Get("artist")
		limitStr := r.URL.Query().Get("limit")
		limit := 10
		if l, err := strconv.Atoi(limitStr); err == nil { limit = l }
		if artist == "" { http.Error(w, `{"error":"falta el artista"}`, 400); return }
		payload, _ := json.Marshal(map[string]interface{}{"artistName": artist, "limit": limit})
		jsonStr(w, backend.GetSimilarArtists(string(payload)))
	})
}
