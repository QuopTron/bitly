// Command server is the desktop entry point for the Go backend.
// It initializes all modules via InitGlobalState() and starts an HTTP server
// with endpoints for search, download, streaming, and more.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"

	backend "github.com/zarz/bitly/go_backend"
)

func main() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// Initialize ALL modules (10 providers, search, download, streaming, etc.)
	result := backend.InitGlobalState()
	if strings.Contains(result, `"error"`) {
		log.Fatalf("[server] InitGlobalState failed: %s", result)
	}
	log.Printf("[server] Backend state: %s", result)

	port := os.Getenv("PORT")
	if port == "" {
		port = "55009"
	}

	mux := http.NewServeMux()

	// Health / ping
	mux.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]string{"status": "ok", "version": "1.0.0"})
	})

	// Search tracks
	mux.HandleFunc("/search/tracks", func(w http.ResponseWriter, r *http.Request) {
		query := r.URL.Query().Get("q")
		if query == "" {
			http.Error(w, `{"error":"missing query"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.SearchTracks(query))
	})

	// Search albums
	mux.HandleFunc("/search/albums", func(w http.ResponseWriter, r *http.Request) {
		query := r.URL.Query().Get("q")
		if query == "" {
			http.Error(w, `{"error":"missing query"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.SearchAlbums(query))
	})

	// Search artists
	mux.HandleFunc("/search/artists", func(w http.ResponseWriter, r *http.Request) {
		query := r.URL.Query().Get("q")
		if query == "" {
			http.Error(w, `{"error":"missing query"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.SearchArtists(query))
	})

	// Get metadata
	mux.HandleFunc("/track", func(w http.ResponseWriter, r *http.Request) {
		provider := r.URL.Query().Get("provider")
		id := r.URL.Query().Get("id")
		if provider == "" || id == "" {
			http.Error(w, `{"error":"missing provider or id"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.GetTrack(provider, id))
	})

	mux.HandleFunc("/album", func(w http.ResponseWriter, r *http.Request) {
		provider := r.URL.Query().Get("provider")
		id := r.URL.Query().Get("id")
		if provider == "" || id == "" {
			http.Error(w, `{"error":"missing provider or id"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.GetAlbum(provider, id))
	})

	mux.HandleFunc("/artist", func(w http.ResponseWriter, r *http.Request) {
		provider := r.URL.Query().Get("provider")
		id := r.URL.Query().Get("id")
		if provider == "" || id == "" {
			http.Error(w, `{"error":"missing provider or id"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.GetArtist(provider, id))
	})

	// Streaming: start proxy server for audio
	// Flutter's media player connects here
	mux.HandleFunc("/stream/start", func(w http.ResponseWriter, r *http.Request) {
		result := backend.StartStreamingServer(18765)
		writeJSON(w, result)
	})

	mux.HandleFunc("/stream/stop", func(w http.ResponseWriter, r *http.Request) {
		result := backend.StopStreamingServer()
		writeJSON(w, result)
	})

	// Get stream URL from provider
	mux.HandleFunc("/stream/url", func(w http.ResponseWriter, r *http.Request) {
		provider := r.URL.Query().Get("provider")
		trackID := r.URL.Query().Get("trackId")
		quality := r.URL.Query().Get("quality")
		if quality == "" {
			quality = "FLAC"
		}
		if provider == "" || trackID == "" {
			http.Error(w, `{"error":"missing provider or trackId"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.GetStreamURL(provider, trackID, quality))
	})

	// Stream audio chunk directly (mobile-style, no proxy server)
	// GET /stream/chunk?url=ENCODED_AUDIO_URL&offset=0&length=262144
	mux.HandleFunc("/stream/chunk", func(w http.ResponseWriter, r *http.Request) {
		audioURL := r.URL.Query().Get("url")
		offset := r.URL.Query().Get("offset")
		length := r.URL.Query().Get("length")
		if audioURL == "" {
			http.Error(w, `{"error":"missing url"}`, http.StatusBadRequest)
			return
		}
		if offset == "" {
			offset = "0"
		}
		if length == "" {
			length = "262144"
		}
		writeJSON(w, backend.StreamAudioChunk(audioURL, offset, length))
	})

	// Lyrics
	mux.HandleFunc("/lyrics", func(w http.ResponseWriter, r *http.Request) {
		track := r.URL.Query().Get("track")
		artist := r.URL.Query().Get("artist")
		if track == "" || artist == "" {
			http.Error(w, `{"error":"missing track or artist"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.FetchLyrics(track, artist, 0))
	})

	// Download
	mux.HandleFunc("/download", func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, `{"error":"cannot read body"}`, http.StatusBadRequest)
			return
		}
		result := backend.DownloadTrack(string(body))
		writeJSON(w, result)
	})

	// Download progress
	mux.HandleFunc("/download/progress", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, backend.GetDownloadProgress())
	})

	// Convert file
	mux.HandleFunc("/convert", func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, `{"error":"cannot read body"}`, http.StatusBadRequest)
			return
		}
		result := backend.ConvertFile(string(body))
		writeJSON(w, result)
	})

	// Rescue (ISRC-based)
	mux.HandleFunc("/rescue", func(w http.ResponseWriter, r *http.Request) {
		isrc := r.URL.Query().Get("isrc")
		track := r.URL.Query().Get("track")
		artist := r.URL.Query().Get("artist")
		quality := r.URL.Query().Get("quality")
		if quality == "" {
			quality = "FLAC"
		}
		if isrc == "" {
			http.Error(w, `{"error":"missing isrc"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.RescueTrack(isrc, track, artist, quality))
	})

	// Recommendations
	mux.HandleFunc("/similar/tracks", func(w http.ResponseWriter, r *http.Request) {
		track := r.URL.Query().Get("track")
		artist := r.URL.Query().Get("artist")
		if track == "" {
			http.Error(w, `{"error":"missing track"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.GetSimilarTracks(track, artist, 10))
	})

	// Read file metadata
	mux.HandleFunc("/metadata", func(w http.ResponseWriter, r *http.Request) {
		filePath := r.URL.Query().Get("path")
		if filePath == "" {
			http.Error(w, `{"error":"missing path"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.ReadFileMetadata(filePath))
	})

	// Extensions
	mux.HandleFunc("/extensions", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, backend.GetInstalledExtensions())
	})

	// Library scan
	mux.HandleFunc("/library/scan", func(w http.ResponseWriter, r *http.Request) {
		dir := r.URL.Query().Get("dir")
		if dir == "" {
			http.Error(w, `{"error":"missing dir"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, backend.ScanLibrary(dir))
	})

	mux.HandleFunc("/library/stats", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, backend.GetLibraryStats())
	})

	// --- Server start ---

	addr := fmt.Sprintf("127.0.0.1:%s", port)
	server := &http.Server{Addr: addr, Handler: mux}

	go func() {
		log.Printf("[server] Listening on http://%s", addr)
		log.Printf("[server] Try: curl http://127.0.0.1:%s/ping", port)
		log.Printf("[server] Try: curl \"http://127.0.0.1:%s/search/tracks?q=bohemian+rhapsody\"", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[server] Error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("[server] Shutting down")
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	switch val := v.(type) {
	case string:
		fmt.Fprint(w, val)
	default:
		json.NewEncoder(w).Encode(v)
	}
}
