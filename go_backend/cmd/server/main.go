// Command server is the desktop entry point for the Go backend.
// It initializes all modules via InitGlobalState() and starts an HTTP server
// with ALL endpoints. Flutter connects to this server via HTTP — no AAR needed.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"

	backend "github.com/zarz/bitly/go_backend"
)

func main() {
	log.SetFlags(log.LstdFlags)
	result := backend.InitGlobalState()
	if strings.Contains(result, `"error"`) {
		log.Fatalf("[server] Init failed: %s", result)
	}
	log.Printf("[server] Ready: %s", result)

	port := os.Getenv("PORT")
	if port == "" {
		port = "55009"
	}

	mux := http.NewServeMux()

	// ─── SYSTEM ───────────────────────────────────────────────────
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

	// ─── SEARCH ───────────────────────────────────────────────────
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

	// ─── METADATA ─────────────────────────────────────────────────
	mux.HandleFunc("/track", func(w http.ResponseWriter, r *http.Request) {
		p, id := r.URL.Query().Get("provider"), r.URL.Query().Get("id")
		if p == "" || id == "" { http.Error(w, `{"error":"falta proveedor o id"}`, 400); return }
		jsonStr(w, backend.GetTrack(p, id))
	})
	mux.HandleFunc("/album", func(w http.ResponseWriter, r *http.Request) {
		p, id := r.URL.Query().Get("provider"), r.URL.Query().Get("id")
		if p == "" || id == "" { http.Error(w, `{"error":"falta proveedor o id"}`, 400); return }
		jsonStr(w, backend.GetAlbum(p, id))
	})
	mux.HandleFunc("/artist", func(w http.ResponseWriter, r *http.Request) {
		p, id := r.URL.Query().Get("provider"), r.URL.Query().Get("id")
		if p == "" || id == "" { http.Error(w, `{"error":"falta proveedor o id"}`, 400); return }
		jsonStr(w, backend.GetArtist(p, id))
	})
	mux.HandleFunc("/resolve/isrc", func(w http.ResponseWriter, r *http.Request) {
		isrc := r.URL.Query().Get("isrc")
		if isrc == "" { http.Error(w, `{"error":"falta el ISRC"}`, 400); return }
		jsonStr(w, backend.ResolveISRC(isrc))
	})

	// ─── DOWNLOAD ─────────────────────────────────────────────────
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
		jsonStr(w, backend.ExtensionDownload(ext, trackID, quality, output))
	})
	mux.HandleFunc("/download/progress", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.GetDownloadProgress())
	})
	mux.HandleFunc("/download/cancel", func(w http.ResponseWriter, r *http.Request) {
		id := r.URL.Query().Get("id")
		if id == "" { http.Error(w, `{"error":"falta el id"}`, 400); return }
		ok := backend.CancelDownload(id)
		jsonStr(w, fmt.Sprintf(`{"ok":%t}`, ok))
	})

	// ─── STREAMING ────────────────────────────────────────────────
	mux.HandleFunc("/stream/url", func(w http.ResponseWriter, r *http.Request) {
		p, id := r.URL.Query().Get("provider"), r.URL.Query().Get("trackId")
		quality := r.URL.Query().Get("quality")
		if quality == "" { quality = "FLAC" }
		if p == "" || id == "" { http.Error(w, `{"error":"falta proveedor o trackId"}`, 400); return }
		jsonStr(w, backend.GetStreamURL(p, id, quality))
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
		jsonStr(w, backend.StreamAudioChunk(url, offset, length))
	})

	// ─── STREAM PACKAGE (todo-en-uno) ────────────────────────────
	mux.HandleFunc("/stream/play", func(w http.ResponseWriter, r *http.Request) {
		provider := r.URL.Query().Get("provider")
		trackID := r.URL.Query().Get("trackId")
		quality := r.URL.Query().Get("quality")
		if quality == "" { quality = "FLAC" }
		fetchLyrics := r.URL.Query().Get("lyrics")
		trackName := r.URL.Query().Get("trackName")
		artistName := r.URL.Query().Get("artistName")
		if trackID == "" { http.Error(w, `{"error":"falta trackId"}`, 400); return }
		jsonStr(w, backend.GetStreamPackage(provider, trackID, quality, fetchLyrics, trackName, artistName))
	})

	// ─── LYRICS ───────────────────────────────────────────────────
	mux.HandleFunc("/lyrics", func(w http.ResponseWriter, r *http.Request) {
		track := r.URL.Query().Get("track")
		artist := r.URL.Query().Get("artist")
		durationStr := r.URL.Query().Get("duration")
		var duration int64
		if d, err := strconv.ParseInt(durationStr, 10, 64); err == nil { duration = d }
		if track == "" || artist == "" { http.Error(w, `{"error":"falta canción o artista"}`, 400); return }
		jsonStr(w, backend.FetchLyrics(track, artist, duration))
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

	// ─── SCROBBLE ─────────────────────────────────────────────────
	mux.HandleFunc("/scrobble/setup", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		ok := backend.SetupScrobbling(string(body))
		jsonStr(w, fmt.Sprintf(`{"ok":%t}`, ok))
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
		jsonStr(w, backend.ScrobbleTrack(req.TrackJSON, req.SessionKey))
	})

	// ─── PREMIUM ──────────────────────────────────────────────────
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
		jsonStr(w, backend.SetPremiumStatus(req.IsPremium, req.Tier))
	})
	mux.HandleFunc("/premium/check-download", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.CheckDownloadAllowed())
	})

	// ─── PLAYBACK ─────────────────────────────────────────────────
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
		jsonStr(w, backend.MarkPlayed(string(body), duration))
	})
	mux.HandleFunc("/playback/history", func(w http.ResponseWriter, r *http.Request) {
		limitStr := r.URL.Query().Get("limit")
		limit := 20
		if l, err := strconv.Atoi(limitStr); err == nil { limit = l }
		jsonStr(w, backend.GetPlayHistory(limit))
	})
	mux.HandleFunc("/playback/queue", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case "GET":
			jsonStr(w, backend.GetPlayQueue())
		case "POST":
			body, _ := io.ReadAll(r.Body)
			addedBy := r.URL.Query().Get("addedBy")
			if addedBy == "" { addedBy = "user" }
			jsonStr(w, backend.AddToQueue(string(body), addedBy))
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
				jsonStr(w, backend.ReorderQueue(old, newP))
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

	// ─── RESCUE ───────────────────────────────────────────────────
	mux.HandleFunc("/rescue", func(w http.ResponseWriter, r *http.Request) {
		isrc := r.URL.Query().Get("isrc")
		track := r.URL.Query().Get("track")
		artist := r.URL.Query().Get("artist")
		quality := r.URL.Query().Get("quality")
		if quality == "" { quality = "FLAC" }
		if isrc == "" { http.Error(w, `{"error":"falta el ISRC"}`, 400); return }
		jsonStr(w, backend.RescueTrack(isrc, track, artist, quality))
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

	// ─── RECOMMENDATIONS ──────────────────────────────────────────
	mux.HandleFunc("/similar/tracks", func(w http.ResponseWriter, r *http.Request) {
		track := r.URL.Query().Get("track")
		artist := r.URL.Query().Get("artist")
		limitStr := r.URL.Query().Get("limit")
		limit := 10
		if l, err := strconv.Atoi(limitStr); err == nil { limit = l }
		if track == "" { http.Error(w, `{"error":"falta la canción"}`, 400); return }
		jsonStr(w, backend.GetSimilarTracks(track, artist, limit))
	})
	mux.HandleFunc("/similar/artists", func(w http.ResponseWriter, r *http.Request) {
		artist := r.URL.Query().Get("artist")
		limitStr := r.URL.Query().Get("limit")
		limit := 10
		if l, err := strconv.Atoi(limitStr); err == nil { limit = l }
		if artist == "" { http.Error(w, `{"error":"falta el artista"}`, 400); return }
		jsonStr(w, backend.GetSimilarArtists(artist, limit))
	})

	// ─── PLAYLIST ─────────────────────────────────────────────────
	mux.HandleFunc("/playlist/export", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		name := r.URL.Query().Get("name")
		creator := r.URL.Query().Get("creator")
		if name == "" { name = "Playlist" }
		jsonStr(w, backend.ExportPlaylistXSPF(string(body), name, creator))
	})
	mux.HandleFunc("/playlist/parse", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		jsonStr(w, backend.ParsePlaylistXSPF(string(body)))
	})

	// ─── CUE ──────────────────────────────────────────────────────
	mux.HandleFunc("/cue/parse", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		jsonStr(w, backend.ParseCUE(string(body)))
	})

	// ─── CONVERT ──────────────────────────────────────────────────
	mux.HandleFunc("/convert", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		jsonStr(w, backend.ConvertFile(string(body)))
	})

	// ─── LIBRARY ──────────────────────────────────────────────────
	mux.HandleFunc("/library/scan", func(w http.ResponseWriter, r *http.Request) {
		dir := r.URL.Query().Get("dir")
		if dir == "" { http.Error(w, `{"error":"falta el directorio"}`, 400); return }
		jsonStr(w, backend.ScanLibrary(dir))
	})
	mux.HandleFunc("/library/stats", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.GetLibraryStats())
	})

	// ─── METADATA (file) ──────────────────────────────────────────
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
		jsonStr(w, backend.EmbedCover(req.Path, req.Data))
	})

	// ─── EXTENSIONS ───────────────────────────────────────────────
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
		jsonStr(w, backend.InitExtensionSystem(dir, dataDir))
	})

	// ─── CLOUDFLARE SESSIONS ──────────────────────────────────────
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
		jsonStr(w, backend.ExchangeSessionGrant(req.ExtensionID, req.GrantCode))
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
		jsonStr(w, backend.StoreSessionToken(req.ExtensionID, req.Token, req.RefreshToken, req.ExpiresIn))
	})

	// ─── START SERVER ─────────────────────────────────────────────
	addr := fmt.Sprintf("127.0.0.1:%s", port)
	server := &http.Server{Addr: addr, Handler: corsMiddleware(mux)}

	go func() {
		log.Printf("🌐 Go backend server listening on http://%s", addr)
		log.Printf("   Try: curl http://127.0.0.1:%s/ping", port)
		log.Printf("   Try: curl \"http://127.0.0.1:%s/search/tracks?q=queen\"", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[server] Error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("[server] Shutting down")
}

func jsonStr(w http.ResponseWriter, s string) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprint(w, s)
}

// corsMiddleware adds CORS headers for Flutter web or dev tools.
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}
