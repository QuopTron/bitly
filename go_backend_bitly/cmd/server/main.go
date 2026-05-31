package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	gobackend "github.com/zarz/bitly/go_backend_bitly"
)

type playSession struct {
	Key       string
	Status    string // "downloading", "ready", "error"
	Progress  int
	FilePath  string
	Error     string
	CreatedAt time.Time
	TrackName string
	Artist    string
	mu        sync.RWMutex
}

var (
	playSessions   = make(map[string]*playSession)
	playSessionsMu sync.RWMutex
	tempDir        string
)

func init() {
	td, err := os.MkdirTemp("", "bitly-stream-*")
	if err == nil {
		tempDir = td
	} else {
		tempDir = os.TempDir()
	}
}

func genKey() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

const ffmpegURL = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"

func ensureFFmpeg() {
	if _, err := exec.LookPath("ffmpeg"); err == nil {
		log.Println("[FFmpeg] Found in PATH")
		return
	}
	exe, _ := os.Executable()
	dir := filepath.Dir(exe)
	localPath := filepath.Join(dir, "ffmpeg.exe")
	if _, err := os.Stat(localPath); err == nil {
		log.Println("[FFmpeg] Found locally")
		return
	}

	log.Println("[FFmpeg] Not found, downloading...")
	resp, err := http.Get(ffmpegURL)
	if err != nil {
		log.Printf("[FFmpeg] Download failed: %v", err)
		return
	}
	defer resp.Body.Close()

	tmp := filepath.Join(os.TempDir(), "ffmpeg.zip")
	out, _ := os.Create(tmp)
	io.Copy(out, resp.Body)
	out.Close()

	// Extract ffmpeg.exe from zip
	if _, err := exec.LookPath("tar"); err == nil {
		extractDir := filepath.Join(dir, "ffmpeg_temp")
		os.MkdirAll(extractDir, 0755)
		exec.Command("tar", "-xf", tmp, "-C", extractDir).Run()
		filepath.Walk(extractDir, func(path string, info os.FileInfo, err error) error {
			if err == nil && !info.IsDir() && info.Name() == "ffmpeg.exe" {
				os.Rename(path, localPath)
			}
			return nil
		})
		os.RemoveAll(extractDir)
	}
	os.Remove(tmp)

	if _, err := os.Stat(localPath); err == nil {
		log.Printf("[FFmpeg] Downloaded to %s", localPath)
	} else {
		log.Println("[FFmpeg] Could not download FFmpeg. Install manually: https://ffmpeg.org/download.html")
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "55009"
	}

	gobackend.GetDeezerClient()

	if runtime.GOOS == "windows" {
		go ensureFFmpeg()
		go func() {
			if err := gobackend.EnsureYtDlp(); err != nil {
				log.Printf("[YouTube] Auto-install failed: %v", err)
			}
		}()
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", handleIndex)
	mux.HandleFunc("/buscar", handleSearch)
	mux.HandleFunc("/rpc", handleRPC)
	mux.HandleFunc("/play/", handlePlay)
	mux.HandleFunc("/dl/", handleDownload)

	addr := "127.0.0.1:" + port
	fmt.Printf("[bitly-backend] Backend on %s\n", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}

func handlePlay(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/play/")
	parts := strings.SplitN(path, "/", 2)
	key := parts[0]

	if r.Method == "POST" && key == "" {
		var req struct {
			Provider   string `json:"provider"`
			TrackID    string `json:"track_id"`
			TrackName  string `json:"track_name"`
			ArtistName string `json:"artist_name"`
			ISRC       string `json:"isrc"`
			Quality    string `json:"quality"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"invalid json"}`, 400)
			return
		}
		newKey := genKey()
		s := &playSession{
			Key:       newKey,
			Status:    "downloading",
			CreatedAt: time.Now(),
			TrackName: req.TrackName,
			Artist:    req.ArtistName,
		}
		playSessionsMu.Lock()
		playSessions[newKey] = s
		playSessionsMu.Unlock()

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"key":    newKey,
			"status": "downloading",
		})

		go func() {
			ext := ".m4a"
			outPath := filepath.Join(tempDir, newKey+ext)
			payload := map[string]interface{}{
				"track_name":     req.TrackName,
				"artist_name":    req.ArtistName,
				"track_id":       req.TrackID,
				"isrc":           req.ISRC,
				"service":        req.Provider,
				"output_path":    outPath,
				"use_extensions": true,
				"use_fallback":   true,
			}
			pb, _ := json.Marshal(payload)
			result, err := gobackend.DownloadByStrategy(string(pb))
			if err != nil {
				s.mu.Lock()
				s.Status = "error"
				s.Error = err.Error()
				s.mu.Unlock()
				return
			}
			var res map[string]interface{}
			if err := json.Unmarshal([]byte(result), &res); err != nil {
				s.mu.Lock()
				s.Status = "error"
				s.Error = "parse error"
				s.mu.Unlock()
				return
			}
			if success, _ := res["success"].(bool); !success {
				errMsg, _ := res["error"].(string)
				s.mu.Lock()
				s.Status = "error"
				s.Error = errMsg
				s.mu.Unlock()
				return
			}
			fp, _ := res["file_path"].(string)
			s.mu.Lock()
			s.Status = "ready"
			s.FilePath = fp
			s.Progress = 100
			s.mu.Unlock()

			finalDir := filepath.Join(tempDir, "ready")
			os.MkdirAll(finalDir, 0755)
			os.Rename(fp, filepath.Join(finalDir, newKey+filepath.Ext(fp)))
		}()
		return
	}

	if key == "" {
		http.Error(w, `{"error":"missing key"}`, 400)
		return
	}

	playSessionsMu.RLock()
	s, exists := playSessions[key]
	playSessionsMu.RUnlock()
	if !exists {
		http.Error(w, `{"error":"session not found"}`, 404)
		return
	}

	// Status check
	if len(parts) > 1 && parts[1] == "status" {
		s.mu.RLock()
		resp := map[string]interface{}{
			"key":      s.Key,
			"status":   s.Status,
			"progress": s.Progress,
			"track":    s.TrackName,
			"artist":   s.Artist,
		}
		if s.Error != "" {
			resp["error"] = s.Error
		}
		s.mu.RUnlock()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
		return
	}

	// Serve audio file
	s.mu.RLock()
	status := s.Status
	fp := s.FilePath
	s.mu.RUnlock()

	if status != "ready" || fp == "" {
		http.Error(w, `{"error":"not ready"}`, 425)
		return
	}

	w.Header().Set("Content-Type", "audio/mp4")
	w.Header().Set("Accept-Ranges", "bytes")
	http.ServeFile(w, r, fp)
}

func handleDownload(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/dl/")
	path = strings.TrimPrefix(path, "/")
	if path == "" {
		http.Error(w, "missing path", 400)
		return
	}
	fullPath := filepath.Join(tempDir, "ready", filepath.Base(path))
	if _, err := os.Stat(fullPath); os.IsNotExist(err) {
		http.Error(w, "not found", 404)
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	http.ServeFile(w, r, fullPath)
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"servicio": "bitly-backend",
		"version":  "1.2.0",
		"status":   "ok",
	})
}

func handleSearch(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	limite, _ := strconv.Atoi(r.URL.Query().Get("limite"))
	if limite <= 0 || limite > 50 {
		limite = 10
	}
	if q == "" {
		w.WriteHeader(400)
		json.NewEncoder(w).Encode(map[string]string{"error": "query required"})
		return
	}

	client := gobackend.GetDeezerClient()
	ctx := r.Context()

	result, err := client.SearchAll(ctx, q, limite, 0, "")
	if err != nil || result == nil {
		w.WriteHeader(500)
		json.NewEncoder(w).Encode(map[string]string{"error": fmt.Sprintf("search failed: %v", err)})
		return
	}

	type Track struct {
		ID       string `json:"id"`
		Titulo   string `json:"titulo"`
		Artista  string `json:"artista"`
		Album    string `json:"album"`
		Cover    string `json:"cover"`
		Duracion int    `json:"duracion"`
		Fuente   string `json:"fuente"`
	}

	var tracks []Track
	for _, t := range result.Tracks {
		tracks = append(tracks, Track{
			ID:       t.SpotifyID,
			Titulo:   t.Name,
			Artista:  t.Artists,
			Album:    t.AlbumName,
			Cover:    t.Images,
			Duracion: t.DurationMS / 1000,
			Fuente:   "deezer",
		})
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"canciones": tracks,
		"total":     len(tracks),
	})
}

type RPCRequest struct {
	Method string                 `json:"method"`
	Params map[string]interface{} `json:"params"`
}

type RPCResponse struct {
	Result interface{} `json:"result,omitempty"`
	Error  string      `json:"error,omitempty"`
}

func handleRPC(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != "POST" {
		json.NewEncoder(w).Encode(RPCResponse{Error: "method not allowed"})
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		json.NewEncoder(w).Encode(RPCResponse{Error: "cannot read body"})
		return
	}

	var req RPCRequest
	if err := json.Unmarshal(body, &req); err != nil {
		json.NewEncoder(w).Encode(RPCResponse{Error: "invalid JSON: " + err.Error()})
		return
	}

	result, rpcErr := dispatch(req.Method, req.Params)
	if rpcErr != nil {
		json.NewEncoder(w).Encode(RPCResponse{Error: rpcErr.Error()})
		return
	}
	json.NewEncoder(w).Encode(RPCResponse{Result: result})
}

type spotifyURLParts struct {
	Type string
	ID   string
}

func parseSpotifyURL(url string) *spotifyURLParts {
	var typ, id string
	if strings.Contains(url, "open.spotify.com") {
		parts := strings.Split(strings.TrimPrefix(url, "https://"), "/")
		for i, p := range parts {
			if p == "track" || p == "album" || p == "playlist" || p == "artist" {
				typ = p
				if i+1 < len(parts) {
					id = strings.Split(parts[i+1], "?")[0]
				}
				break
			}
		}
	} else if strings.HasPrefix(url, "spotify:") {
		parts := strings.Split(url, ":")
		if len(parts) >= 3 && (parts[1] == "track" || parts[1] == "album" || parts[1] == "playlist" || parts[1] == "artist") {
			typ = parts[1]
			id = parts[2]
		}
	}
	if typ == "" || id == "" {
		return nil
	}
	return &spotifyURLParts{Type: typ, ID: id}
}

func handleBuiltinURL(parts *spotifyURLParts) map[string]interface{} {
	if parts.Type == "track" {
		result, err := gobackend.ConvertSpotifyToDeezer("track", parts.ID)
		if err == nil && result != "" {
			var deezerData struct {
				DeezerID int `json:"deezer_id"`
			}
			if json.Unmarshal([]byte(result), &deezerData) == nil && deezerData.DeezerID > 0 {
				did := strconv.Itoa(deezerData.DeezerID)
				meta, err := gobackend.GetDeezerMetadata("track", did)
				if err == nil && meta != "" {
					var trackMeta map[string]interface{}
					if json.Unmarshal([]byte(meta), &trackMeta) == nil {
						trackName, _ := trackMeta["name"].(string)
						artistName, _ := trackMeta["artist_name"].(string)
						albumName, _ := trackMeta["album_name"].(string)
						coverURL, _ := trackMeta["cover_url"].(string)
						duration, _ := trackMeta["duration"].(float64)
						return map[string]interface{}{
							"type":         "track",
							"extension_id": "__deezer",
							"track": map[string]interface{}{
								"id":          parts.ID,
								"name":        trackName,
								"artists":     artistName,
								"album_name":  albumName,
								"cover_url":   coverURL,
								"duration_ms": int(duration * 1000),
								"source":      "deezer",
							},
						}
					}
				}
			}
		}
	}
	if parts.Type == "album" {
		result, err := gobackend.ConvertSpotifyToDeezer("album", parts.ID)
		if err == nil && result != "" {
			var deezerData struct {
				DeezerID int `json:"deezer_id"`
			}
			if json.Unmarshal([]byte(result), &deezerData) == nil && deezerData.DeezerID > 0 {
				did := strconv.Itoa(deezerData.DeezerID)
				meta, err := gobackend.GetDeezerMetadata("album", did)
				if err == nil && meta != "" {
					var albumMeta map[string]interface{}
					if json.Unmarshal([]byte(meta), &albumMeta) == nil {
						return map[string]interface{}{
							"type":         "album",
							"extension_id": "__deezer",
							"name":         albumMeta["name"],
							"artist":       albumMeta["artist_name"],
							"cover":        albumMeta["cover_url"],
						}
					}
				}
			}
		}
	}
	return nil
}

func searchWithDeezer(query string, limit int) (string, error) {
	if limit <= 0 || limit > 50 {
		limit = 10
	}
	client := gobackend.GetDeezerClient()
	ctx := context.Background()
	result, err := client.SearchAll(ctx, query, limit, 0, "")
	if err != nil || result == nil {
		return "[]", nil
	}
	type trackItem struct {
		ID       string `json:"id"`
		Name     string `json:"name"`
		Artists  string `json:"artists"`
		Album    string `json:"album_name"`
		CoverURL string `json:"cover_url"`
		Duration int    `json:"duration_ms"`
		Source   string `json:"source"`
	}
	var tracks []trackItem
	for _, t := range result.Tracks {
		tracks = append(tracks, trackItem{
			ID:       t.SpotifyID,
			Name:     t.Name,
			Artists:  t.Artists,
			Album:    t.AlbumName,
			CoverURL: t.Images,
			Duration: t.DurationMS,
			Source:   "deezer",
		})
	}
	b, _ := json.Marshal(tracks)
	return string(b), nil
}

func convertM4aToFlac(inputPath string) (string, error) {
	if !strings.HasSuffix(strings.ToLower(inputPath), ".m4a") {
		return inputPath, nil
	}
	outputPath := inputPath[:len(inputPath)-4] + ".flac"

	// Try ffmpeg first
	if ffmpeg, err := exec.LookPath("ffmpeg"); err == nil {
		cmd := exec.Command(ffmpeg,
			"-v", "error",
			"-i", inputPath,
			"-c:a", "flac",
			"-compression_level", "8",
			"-y", outputPath,
		)
		if err := cmd.Run(); err == nil {
			os.Remove(inputPath)
			return outputPath, nil
		}
	}

	// Try Bitly-bundled ffmpeg
	if ffmpeg, err := exec.LookPath("ffmpeg.exe"); err == nil {
		cmd := exec.Command(ffmpeg,
			"-v", "error",
			"-i", inputPath,
			"-c:a", "flac",
			"-compression_level", "8",
			"-y", outputPath,
		)
		if err := cmd.Run(); err == nil {
			os.Remove(inputPath)
			return outputPath, nil
		}
	}

	return inputPath, nil
}

func dispatch(method string, params map[string]interface{}) (interface{}, error) {
	sp := func(key string) string {
		v, _ := params[key].(string)
		return v
	}
	sn := func(key string) int {
		switch v := params[key].(type) {
		case float64:
			return int(v)
		case int:
			return v
		default:
			return 0
		}
	}
	bd := func(key string) bool {
		v, _ := params[key].(bool)
		return v
	}

	switch method {
	case "ping":
		return "pong", nil

	// --- Core ---
	case "InitMasterDatabaseJSON":
		return "ok", gobackend.InitMasterDatabase(sp("request"))

	case "checkGitHubUpdate":
		// Los parámetros vienen directamente como mapa desde Flutter
		channel := sp("channel")
		currentVersion := sp("current_version")
		repo := sp("repo")
		if channel == "" {
			channel = "stable"
		}
		if currentVersion == "" {
			currentVersion = "0.0.0"
		}
		// Crear JSON para la función
		paramsMap := map[string]string{
			"channel":         channel,
			"current_version": currentVersion,
			"repo":            repo,
		}
		paramsJSON, _ := json.Marshal(paramsMap)
		return gobackend.CheckGitHubUpdateJSON(string(paramsJSON))

	case "checkAvailability":
		return gobackend.CheckAvailability(sp("spotify_id"), sp("isrc"))

	case "setNetworkCompatibilityOptions":
		gobackend.SetNetworkCompatibilityOptions(bd("allow_http"), bd("insecure_tls"))
		return "ok", nil

	case "exitApp":
		os.Exit(0)
		return "ok", nil

	case "cleanupConnections":
		gobackend.CleanupConnections()
		return "ok", nil

	// --- Premium ---
	case "validarCodigoPremium":
		codigo := sp("codigo")
		res := gobackend.ValidarCodigoPremium(codigo)
		if !res.Valido {
			return nil, fmt.Errorf("%s", res.ErrorMsg)
		}
		result := map[string]interface{}{
			"valido": true,
		}
		if res.Expiry > 0 {
			result["expiry"] = res.Expiry
		}
		return result, nil

	case "verificarPremium":
		isPremium := sn("is_premium") == 1
		premiumUntil := int64(sn("premium_until"))
		err := gobackend.VerificarPremium(isPremium, premiumUntil)
		if err != nil {
			return nil, err
		}
		return map[string]interface{}{"valido": true}, nil

	// --- Downloads ---
	case "downloadByStrategy":
		return gobackend.DownloadByStrategy(sp("request"))

	case "getDownloadProgress":
		return gobackend.GetDownloadProgress(), nil

	case "getAllDownloadProgress":
		return gobackend.GetAllDownloadProgress(), nil

	case "initItemProgress":
		gobackend.InitItemProgress(sp("item_id"))
		return "ok", nil

	case "finishItemProgress":
		gobackend.FinishItemProgress(sp("item_id"))
		return "ok", nil

	case "clearItemProgress":
		gobackend.ClearItemProgress(sp("item_id"))
		return "ok", nil

	case "cancelDownload":
		gobackend.CancelDownload(sp("item_id"))
		return "ok", nil

	case "setDownloadDirectory":
		return "ok", gobackend.SetDownloadDirectory(sp("path"))

	case "checkDuplicate":
		return gobackend.CheckDuplicate(sp("output_dir"), sp("isrc"))

	case "buildFilename":
		return gobackend.BuildFilename(sp("template"), sp("metadata"))

	case "sanitizeFilename":
		return gobackend.SanitizeFilename(sp("filename")), nil

	// --- Track metadata & lyrics ---
	case "fetchLyrics":
		return gobackend.FetchLyrics(sp("spotify_id"), sp("track_name"), sp("artist_name"), int64(sn("duration_ms")))

	case "getLyricsLRC":
		return gobackend.GetLyricsLRC(sp("spotify_id"), sp("track_name"), sp("artist_name"), sp("file_path"), int64(sn("duration_ms")))

	case "getLyricsLRCWithSource":
		return gobackend.GetLyricsLRCWithSource(sp("spotify_id"), sp("track_name"), sp("artist_name"), sp("file_path"), int64(sn("duration_ms")))

	case "embedLyricsToFile":
		return gobackend.EmbedLyricsToFile(sp("file_path"), sp("lyrics"))

	case "getLyricsProviders":
		return gobackend.GetLyricsProvidersJSON()

	case "setLyricsProviders":
		return "ok", gobackend.SetLyricsProvidersJSON(sp("providers_json"))

	case "getAvailableLyricsProviders":
		return gobackend.GetAvailableLyricsProvidersJSON()

	case "setLyricsFetchOptions":
		return "ok", gobackend.SetLyricsFetchOptionsJSON(sp("options_json"))

	case "getLyricsFetchOptions":
		return gobackend.GetLyricsFetchOptionsJSON()

	case "downloadCoverToFile":
		return "ok", gobackend.DownloadCoverToFile(sp("cover_url"), sp("output_path"), bd("max_quality"))

	case "extractCoverToFile":
		return "ok", gobackend.ExtractCoverToFile(sp("audio_path"), sp("output_path"))

	case "fetchAndSaveLyrics":
		return "ok", gobackend.FetchAndSaveLyrics(sp("track_name"), sp("artist_name"), sp("spotify_id"), int64(sn("duration_ms")), sp("output_path"), sp("audio_file_path"))

	case "reEnrichFile":
		return gobackend.ReEnrichFile(sp("request_json"))

	case "readFileMetadata":
		return gobackend.ReadFileMetadata(sp("file_path"))

	case "editFileMetadata":
		return gobackend.EditFileMetadata(sp("file_path"), sp("metadata_json"))

	case "rewriteSplitArtistTags":
		return gobackend.RewriteSplitArtistTagsExport(sp("file_path"), sp("artist"), sp("album_artist"))

	case "readAudioMetadata":
		return gobackend.ReadAudioMetadataJSON(sp("file_path"))

	case "runPostProcessing":
		return gobackend.RunPostProcessingJSON(sp("file_path"), sp("metadata"))

	case "runPostProcessingV2":
		return gobackend.RunPostProcessingV2JSON(sp("input"), sp("metadata"))

	case "getPostProcessingProviders":
		return gobackend.GetPostProcessingProvidersJSON()

	// --- Extension system ---
	case "initExtensionSystem":
		return "ok", gobackend.InitExtensionSystem(sp("extensions_dir"), sp("data_dir"))

	case "loadExtensionsFromDir":
		return gobackend.LoadExtensionsFromDir(sp("dir_path"))

	case "loadExtensionFromPath":
		return gobackend.LoadExtensionFromPath(sp("file_path"))

	case "unloadExtension":
		return "ok", gobackend.UnloadExtensionByID(sp("extension_id"))

	case "removeExtension":
		return "ok", gobackend.RemoveExtensionByID(sp("extension_id"))

	case "upgradeExtension":
		return gobackend.UpgradeExtensionFromPath(sp("file_path"))

	case "checkExtensionUpgrade":
		return gobackend.CheckExtensionUpgradeFromPath(sp("file_path"))

	case "getInstalledExtensions":
		return gobackend.GetInstalledExtensions()

	case "setExtensionEnabled":
		return "ok", gobackend.SetExtensionEnabledByID(sp("extension_id"), bd("enabled"))

	case "invokeExtensionAction":
		return gobackend.InvokeExtensionActionJSON(sp("extension_id"), sp("action"))

	case "cleanupExtensions":
		gobackend.CleanupExtensions()
		return "ok", nil

	case "searchTracksWithMetadataProviders":
		result, err := gobackend.SearchTracksWithMetadataProvidersJSON(sp("query"), sn("limit"), bd("include_extensions"))
		if err != nil || result == "[]" || result == "null" {
			return searchWithDeezer(sp("query"), sn("limit"))
		}
		return result, err

	case "getProviderPriority":
		return gobackend.GetProviderPriorityJSON()

	case "setProviderPriority":
		return "ok", gobackend.SetProviderPriorityJSON(sp("priority"))

	case "setDownloadFallbackExtensionIds":
		return "ok", gobackend.SetExtensionFallbackProviderIDsJSON(sp("extension_ids"))

	case "getMetadataProviderPriority":
		return gobackend.GetMetadataProviderPriorityJSON()

	case "setMetadataProviderPriority":
		return "ok", gobackend.SetMetadataProviderPriorityJSON(sp("priority"))

	case "getExtensionSettings":
		return gobackend.GetExtensionSettingsJSON(sp("extension_id"))

	case "setExtensionSettings":
		return "ok", gobackend.SetExtensionSettingsJSON(sp("extension_id"), sp("settings"))

	case "checkExtensionHealth":
		return gobackend.CheckExtensionHealthJSON(sp("extension_id"))

	case "getExtensionPendingAuth":
		return gobackend.GetExtensionPendingAuthJSON(sp("extension_id"))

	case "setExtensionAuthCode":
		gobackend.SetExtensionAuthCodeByID(sp("extension_id"), sp("auth_code"))
		return "ok", nil

	case "setExtensionTokens":
		gobackend.SetExtensionTokensByID(sp("extension_id"), sp("access_token"), sp("refresh_token"), sn("expires_in"))
		return "ok", nil

	case "clearExtensionPendingAuth":
		gobackend.ClearExtensionPendingAuthByID(sp("extension_id"))
		return "ok", nil

	case "isExtensionAuthenticated":
		return strconv.FormatBool(gobackend.IsExtensionAuthenticatedByID(sp("extension_id"))), nil

	case "getAllPendingAuthRequests":
		return gobackend.GetAllPendingAuthRequestsJSON()

	case "getPendingFFmpegCommand":
		return gobackend.GetPendingFFmpegCommandJSON(sp("command_id"))

	case "setFFmpegCommandResult":
		gobackend.SetFFmpegCommandResultByID(sp("command_id"), bd("success"), sp("output"), sp("error"))
		return "ok", nil

	case "getAllPendingFFmpegCommands":
		return gobackend.GetAllPendingFFmpegCommandsJSON()

	case "customSearchWithExtension":
		return gobackend.CustomSearchWithExtensionJSON(sp("extension_id"), sp("query"), sp("options"))

	case "getSearchProviders":
		result, err := gobackend.GetSearchProvidersJSON()
		if err != nil {
			return "", err
		}
		return `[{"id":"__deezer","name":"Deezer","type":"music","has_custom_search":true,"search_behavior":{"primary":true,"filters":["track","artist","album","playlist"]}}]` + result[1:], nil

	case "handleURLWithExtension":
		url := sp("url")
		if strings.Contains(url, "open.spotify.com") || strings.Contains(url, "spotify:") {
			parts := parseSpotifyURL(url)
			if parts != nil {
				result := handleBuiltinURL(parts)
				if result != nil {
					b, _ := json.Marshal(result)
					return string(b), nil
				}
			}
		}
		return gobackend.HandleURLWithExtensionJSON(url)

	case "findURLHandler":
		url := sp("url")
		if strings.Contains(url, "open.spotify.com") || strings.Contains(url, "spotify:") {
			return "__deezer", nil
		}
		if strings.Contains(url, "deezer.com") {
			return "__deezer", nil
		}
		return gobackend.FindURLHandlerJSON(url), nil

	case "getURLHandlers":
		return gobackend.GetURLHandlersJSON()

	case "getExtensionHomeFeed":
		return gobackend.GetExtensionHomeFeedJSON(sp("extension_id"))

	case "getExtensionBrowseCategories":
		return gobackend.GetExtensionBrowseCategoriesJSON(sp("extension_id"))

	case "cancelExtensionRequest":
		gobackend.CancelExtensionRequestJSON(sp("request_id"))
		return "ok", nil

	// --- Extension store ---
	case "initExtensionStore":
		return "ok", gobackend.InitExtensionStoreJSON(sp("cache_dir"))

	case "setStoreRegistryUrl":
		return "ok", gobackend.SetStoreRegistryURLJSON(sp("registry_url"))

	case "getStoreRegistryUrl":
		return gobackend.GetStoreRegistryURLJSON()

	case "clearStoreRegistryUrl":
		return "ok", gobackend.ClearStoreRegistryURLJSON()

	case "getStoreExtensions":
		return gobackend.GetStoreExtensionsJSON(bd("force_refresh"))

	case "searchStoreExtensions":
		return gobackend.SearchStoreExtensionsJSON(sp("query"), sp("category"))

	case "getStoreCategories":
		return gobackend.GetStoreCategoriesJSON()

	case "downloadStoreExtension":
		return gobackend.DownloadStoreExtensionJSON(sp("extension_id"), sp("dest_dir"))

	case "clearStoreCache":
		return "ok", gobackend.ClearStoreCacheJSON()

	// --- Deezer ---
	case "getDeezerRelatedArtists":
		return gobackend.GetDeezerRelatedArtists(sp("artist_id"), sn("limit"))

	case "getProviderMetadata":
		return gobackend.GetProviderMetadataJSON(sp("provider_id"), sp("resource_type"), sp("resource_id"))

	case "searchDeezerByISRC":
		return gobackend.SearchDeezerByISRCForItemID(sp("isrc"), sp("item_id"))

	case "getDeezerExtendedMetadata":
		return gobackend.GetDeezerExtendedMetadata(sp("track_id"))

	case "convertSpotifyToDeezer":
		return gobackend.ConvertSpotifyToDeezer(sp("resource_type"), sp("spotify_id"))

	// --- Cache ---
	case "preWarmTrackCache":
		return gobackend.PreWarmTrackCacheJSON(sp("tracks"))

	case "getTrackCacheSize":
		return strconv.Itoa(gobackend.GetTrackCacheSize()), nil

	case "clearTrackCache":
		gobackend.ClearTrackIDCache()
		return "ok", nil

	// --- Library scan ---
	case "setLibraryCoverCacheDir":
		gobackend.SetLibraryCoverCacheDirJSON(sp("cache_dir"))
		return "ok", nil

	case "scanLibraryFolder":
		return gobackend.ScanLibraryFolderJSON(sp("folder_path"))

	case "scanLibraryFolderIncremental":
		return gobackend.ScanLibraryFolderIncrementalJSON(sp("folder_path"), sp("existing_files"))

	case "scanLibraryFolderIncrementalFromSnapshot":
		return gobackend.ScanLibraryFolderIncrementalFromSnapshotJSON(sp("folder_path"), sp("snapshot_path"))

	case "getLibraryScanProgress":
		return gobackend.GetLibraryScanProgressJSON(), nil

	case "cancelLibraryScan":
		gobackend.CancelLibraryScanJSON()
		return "ok", nil

	// --- Download History (Go-managed to avoid DB contention) ---
	case "upsertDownloadEntry":
		var entry gobackend.DownloadHistoryEntry
		if err := json.Unmarshal([]byte(sp("request")), &entry); err != nil {
			return nil, fmt.Errorf("invalid entry: %w", err)
		}
		return "ok", gobackend.UpsertDownloadEntry(entry)

	case "deleteDownloadEntriesByIDs":
		var ids []string
		if err := json.Unmarshal([]byte(sp("request")), &ids); err != nil {
			return nil, fmt.Errorf("invalid ids: %w", err)
		}
		return "ok", gobackend.DeleteDownloadEntriesByIDs(ids)

	case "deleteDownloadEntriesByPaths":
		var paths []string
		if err := json.Unmarshal([]byte(sp("request")), &paths); err != nil {
			return nil, fmt.Errorf("invalid paths: %w", err)
		}
		return "ok", gobackend.DeleteDownloadEntriesByPaths(paths)

	case "deleteDownloadEntriesByTrackMatch":
		return "ok", gobackend.DeleteDownloadEntriesByTrackMatch(sp("track_name"), sp("artist_name"))

	case "getDownloadHistory":
		result, err := gobackend.GetDownloadHistory(sn("limit"), sn("offset"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "clearDownloadHistory":
		return "ok", gobackend.ClearDownloadHistory()

	case "getDownloadHistoryCount":
		return gobackend.GetDownloadHistoryCount()

	case "getDownloadHistoryGroupedCounts":
		result, err := gobackend.GetDownloadHistoryGroupedCounts()
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getDownloadEntryByID":
		result, err := gobackend.GetDownloadEntryByID(sp("request"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getDownloadEntryBySpotifyID":
		result, err := gobackend.GetDownloadEntryBySpotifyID(sp("request"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getDownloadEntryByISRC":
		result, err := gobackend.GetDownloadEntryByISRC(sp("request"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "findDownloadEntryByTrackAndArtist":
		result, err := gobackend.FindDownloadEntryByTrackAndArtist(sp("track_name"), sp("artist_name"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "updateDownloadFilePath":
		return "ok", gobackend.UpdateDownloadFilePath(sp("id"), sp("file_path"))

	case "updateDownloadAudioMetadata":
		var entry gobackend.DownloadHistoryEntry
		if err := json.Unmarshal([]byte(sp("request")), &entry); err != nil {
			return nil, fmt.Errorf("invalid entry: %w", err)
		}
		return "ok", gobackend.UpdateDownloadAudioMetadata(entry)

	case "getDownloadHistoryFilePaths":
		result, err := gobackend.GetDownloadHistoryFilePaths()
		if err != nil {
			return nil, err
		}
		return result, nil

	case "existingDownloadTrackKeys":
		result, err := gobackend.ExistingDownloadTrackKeys(sp("request"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getDownloadAlbumTracks":
		result, err := gobackend.GetDownloadAlbumTracks(sp("album"), sp("artist"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getDownloadArtistTracks":
		result, err := gobackend.GetDownloadArtistTracks(sp("artist"))
		if err != nil {
			return nil, err
		}
		return result, nil

	// --- Local Library (Go-managed) ---
	case "upsertLocalLibraryEntry":
		var entry gobackend.DownloadHistoryEntry
		if err := json.Unmarshal([]byte(sp("request")), &entry); err != nil {
			return nil, fmt.Errorf("invalid entry: %w", err)
		}
		return "ok", gobackend.UpsertLocalLibraryEntry(entry)

	case "clearLocalLibrary":
		return "ok", gobackend.ClearLocalLibrary()

	case "deleteLocalLibraryEntriesByPaths":
		var paths []string
		if err := json.Unmarshal([]byte(sp("request")), &paths); err != nil {
			return nil, fmt.Errorf("invalid paths: %w", err)
		}
		return "ok", gobackend.DeleteLocalLibraryEntriesByPaths(paths)

	case "deleteLocalLibraryEntryByID":
		return "ok", gobackend.DeleteLocalLibraryEntryByID(sp("id"))

	case "getLocalLibraryPage":
		result, err := gobackend.GetLocalLibraryPage(sn("limit"), sn("offset"), sp("searchQuery"), sp("sortMode"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getLocalLibraryCount":
		return gobackend.GetLocalLibraryCount(sp("searchQuery"))

	case "getLocalLibraryAlbumGroups":
		result, err := gobackend.GetLocalLibraryAlbumGroups(sn("limit"), sn("offset"), sp("searchQuery"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getLocalLibraryAlbumGroupCount":
		return gobackend.GetLocalLibraryAlbumGroupCount(sp("searchQuery"))

	case "getLocalLibraryEntryByID":
		result, err := gobackend.GetLocalLibraryEntryByID(sp("id"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getLocalLibraryEntryByIsrc":
		result, err := gobackend.GetLocalLibraryEntryByIsrc(sp("isrc"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "findLocalLibraryEntryByTrackAndArtist":
		result, err := gobackend.FindLocalLibraryEntryByTrackAndArtist(sp("track_name"), sp("artist_name"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getLocalLibraryCoverPaths":
		result, err := gobackend.GetLocalLibraryCoverPaths()
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getLocalLibraryEntriesWithPathsPage":
		result, err := gobackend.GetLocalLibraryEntriesWithPathsPage(sn("limit"), sn("offset"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "updateLocalLibraryFileModTimes":
		return "ok", gobackend.UpdateLocalLibraryFileModTimes(sp("entries"))

	case "updateLocalLibraryAudioMetadata":
		return "ok", gobackend.UpdateLocalLibraryAudioMetadata(sp("request"))

	case "getLocalLibraryArtistTracks":
		result, err := gobackend.GetLocalLibraryArtistTracks(sp("artist"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getLocalLibraryAlbumTracks":
		result, err := gobackend.GetLocalLibraryAlbumTracks(sp("album"), sp("artist"))
		if err != nil {
			return nil, err
		}
		return result, nil

	// --- Logging ---
	case "getLogs":
		return "[]", nil

	case "getLogsSince":
		return `{"logs":[],"next_index":0}`, nil

	case "getLogCount":
		return "0", nil

	case "setLoggingEnabled":
		return "ok", nil

	case "clearLogs":
		return "ok", nil

	// --- CUE sheets ---
	case "parseCueSheet":
		return gobackend.ParseCueSheet(sp("cue_path"), sp("audio_dir"))

	case "convertAudioFile":
		outputPath, err := convertM4aToFlac(sp("input_path"))
		if err != nil {
			return sp("input_path"), nil
		}
		return outputPath, nil

	case "scanCueSheetForLibrary":
		return gobackend.ScanCueSheetForLibrary(sp("cue_path"), sp("audio_dir"), sp("virtual_path_prefix"), int64(sn("file_mod_time")))

	// --- Filename ---
	case "checkDuplicatesBatch":
		return gobackend.CheckDuplicatesBatch(sp("output_dir"), sp("tracks_json"))

	case "preBuildDuplicateIndex":
		return "ok", gobackend.PreBuildDuplicateIndex(sp("output_dir"))

	case "invalidateDuplicateIndex":
		gobackend.InvalidateDuplicateIndex(sp("output_dir"))
		return "ok", nil

	case "allowDownloadDir":
		gobackend.AllowDownloadDir(sp("path"))
		return "ok", nil

	case "getTrackCacheSizeBytes":
		return "0", nil

	// --- Playback Control ---
	case "playbackPlayTrack":
		return gobackend.PlaybackPlayTrack(sp("track_json")), nil

	case "playbackPause":
		return gobackend.PlaybackPause(), nil

	case "playbackResume":
		return gobackend.PlaybackResume(), nil

	case "playbackStop":
		return gobackend.PlaybackStop(), nil

	case "playbackSeek":
		return gobackend.PlaybackSeek(int64(sn("position_ms"))), nil

	case "playbackNext":
		return gobackend.PlaybackNext(), nil

	case "playbackPrevious":
		return gobackend.PlaybackPrevious(), nil

	case "playbackSetQueue":
		return gobackend.PlaybackSetQueue(sp("tracks_json")), nil

	case "playbackAddToQueue":
		return gobackend.PlaybackAddToQueue(sp("tracks_json")), nil

	case "playbackSetShuffle":
		return gobackend.PlaybackSetShuffle(bd("enabled")), nil

	case "playbackSetRepeat":
		return gobackend.PlaybackSetRepeat(sp("mode")), nil

	case "playbackTrackCompleted":
		return gobackend.PlaybackTrackCompleted(), nil

	case "playbackGetState":
		return gobackend.PlaybackGetState(), nil

	case "playbackGetHistory":
		return gobackend.PlaybackGetHistory(sn("limit")), nil

	case "playbackGetQueue":
		return gobackend.PlaybackGetQueue(), nil

	case "playbackRemoveFromQueue":
		return gobackend.PlaybackRemoveFromQueue(sn("index")), nil

	case "playbackClearQueue":
		return gobackend.PlaybackClearQueue(), nil

	case "playbackUpdatePosition":
		gobackend.PlaybackUpdatePosition(int64(sn("position_ms")))
		return "ok", nil

	// --- Video ---
	case "searchYouTubeVideo":
		return gobackend.SearchYouTubeVideo(sp("track_name"), sp("artist_name"))
	case "downloadYouTubeVideo":
		return gobackend.DownloadYouTubeVideo(sp("track_name"), sp("artist_name"), sp("output_path"))

	// --- Favorites (Likes) ---
	case "upsertFavorite":
		return "ok", gobackend.UpsertFavorite(sp("request"))

	case "deleteFavorite":
		return "ok", gobackend.DeleteFavorite(sp("request"))

	case "getAllFavorites":
		result, err := gobackend.GetAllFavorites(sp("type"))
		if err != nil {
			return nil, err
		}
		return result, nil

	// --- Collections ---
	case "upsertCollection":
		return "ok", gobackend.UpsertCollection(sp("request"))

	case "deleteCollection":
		return "ok", gobackend.DeleteCollection(sp("request"))

	case "addToCollection":
		return "ok", gobackend.AddToCollection(sp("collection_id"), sp("item_id"), sp("added_at"), sp("item_json"))

	case "removeFromCollection":
		return "ok", gobackend.RemoveFromCollection(sp("collection_id"), sp("request"))

	case "getAllCollections":
		result, err := gobackend.GetAllCollections()
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getCollectionItems":
		result, err := gobackend.GetCollectionItems(sp("request"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getAllCollectionItems":
		result, err := gobackend.GetAllCollectionItems()
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getCollectionItemIDsByItemID":
		result, err := gobackend.GetCollectionItemIDsByItemID(sp("item_id"))
		if err != nil {
			return nil, err
		}
		return result, nil

	// --- Play History ---
	case "logPlay":
		return "ok", gobackend.LogPlay(sp("track_id"), sp("track_name"), sp("artist_name"), sp("album_name"), sp("played_at"), sn("duration_ms"), sn("percentage"))

	case "getRecentPlays":
		result, err := gobackend.GetRecentPlays(sn("limit"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "clearPlayHistory":
		return "ok", gobackend.ClearPlayHistory()

	// --- Play Aggregates ---
	case "incrementPlayCount":
		return "ok", gobackend.IncrementPlayCount(sp("request"), sp("type"))

	case "getPlayAggregates":
		result, err := gobackend.GetPlayAggregates(sp("type"))
		if err != nil {
			return nil, err
		}
		return result, nil

	// --- Stats (Total, Top lists, Secrets) ---
	case "getTotalStats":
		result, err := gobackend.GetTotalStats()
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getTopTracks":
		result, err := gobackend.GetTopTracks(sn("limit"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getTopAlbums":
		result, err := gobackend.GetTopAlbums(sn("limit"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getTopArtists":
		result, err := gobackend.GetTopArtists(sn("limit"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getSecretCounter":
		return gobackend.GetSecretCounter(sp("key"))

	case "incrementNightPlays":
		return "ok", gobackend.IncrementNightPlays()

	case "updateAlbumStreak":
		return "ok", gobackend.UpdateAlbumStreak(sn("streak"))

	case "isSecretUnlocked":
		return gobackend.IsSecretUnlocked(sp("key"))

	case "unlockSecret":
		return "ok", gobackend.UnlockSecret(sp("key"))

	case "getUnlockedSecrets":
		result, err := gobackend.GetUnlockedSecrets()
		if err != nil {
			return nil, err
		}
		return result, nil

	case "clearAllStats":
		return "ok", gobackend.ClearAllStats()

	// --- Download Queue (Go-managed in master DB) ---
	case "saveDownloadQueue":
		return "ok", gobackend.SaveDownloadQueue(sp("items"))

	case "loadDownloadQueue":
		result, err := gobackend.LoadDownloadQueue()
		if err != nil {
			return nil, err
		}
		return result, nil

	case "getPendingDownloadQueueRows":
		result, err := gobackend.GetPendingDownloadQueueRows()
		if err != nil {
			return nil, err
		}
		return result, nil

	case "replacePendingDownloadQueueRows":
		return "ok", gobackend.ReplacePendingDownloadQueueRows(sp("rows"))

	// --- Recent Access ---
	case "upsertRecentAccessRow":
		return "ok", gobackend.UpsertRecentAccessRow(sp("key"), sp("json"), sp("accessed_at"))

	case "getRecentAccessRows":
		result, err := gobackend.GetRecentAccessRows(sn("limit"))
		if err != nil {
			return nil, err
		}
		return result, nil

	case "deleteRecentAccessRow":
		return "ok", gobackend.DeleteRecentAccessRow(sp("key"))

	case "clearRecentAccessRows":
		return "ok", gobackend.ClearRecentAccessRows()

	// --- Hidden Download IDs ---
	case "getHiddenRecentDownloadIds":
		result, err := gobackend.GetHiddenRecentDownloadIds()
		if err != nil {
			return nil, err
		}
		return result, nil

	case "addHiddenRecentDownloadId":
		return "ok", gobackend.AddHiddenRecentDownloadId(sp("download_id"))

	case "clearHiddenRecentDownloadIds":
		return "ok", gobackend.ClearHiddenRecentDownloadIds()
	// --- Local Library Maintenance ---
	case "resetDatabase":
		return "ok", gobackend.ResetDatabase()

	case "cleanupLocalLibraryMissingFiles":
		return gobackend.CleanupLocalLibraryMissingFiles(sp("paths_json"))

	case "replaceLocalLibraryConvertedItem":
		return "ok", gobackend.ReplaceLocalLibraryConvertedItem(sp("request_json"))

	case "getLocalLibrarySingleTrackCount":
		return gobackend.GetLocalLibrarySingleTrackCount(sp("search_query"))

	case "getTranslatedLyricsLRC":
		return gobackend.GetTranslatedLyricsLRC(sp("spotify_id"), sp("track_name"), sp("artist_name"), int64(sn("duration_ms")), sp("language"))
	case "setTranslationLanguageJSON":
		return "ok", gobackend.SaveTranslationLanguage(sp("language"))
	case "getTranslationLanguageJSON":
		result, err := gobackend.LoadTranslationLanguage()
		if err != nil {
			return nil, err
		}
		if result == "" {
			return "es", nil
		}
		return result, nil

	// --- App Settings ---
	case "saveAppSettings":
		return "ok", gobackend.SaveAppSettings(sp("value"))
	case "loadAppSettings":
		result, err := gobackend.LoadAppSettings()
		if err != nil {
			return nil, err
		}
		return result, nil

	// --- JSON-suffixed aliases (Flutter uses these names) ---
	case "cancelExtensionRequestJSON":
		gobackend.CancelExtensionRequestJSON(sp("request_id"))
		return "ok", nil
	case "clearStoreCacheJSON":
		return "ok", gobackend.ClearStoreCacheJSON()
	case "clearStoreRegistryURLJSON":
		return "ok", gobackend.ClearStoreRegistryURLJSON()
	case "downloadStoreExtensionJSON":
		return gobackend.DownloadStoreExtensionJSON(sp("extension_id"), sp("dest_dir"))
	case "getAvailableLyricsProvidersJSON":
		return gobackend.GetAvailableLyricsProvidersJSON()
	case "getExtensionSettingsJSON":
		return gobackend.GetExtensionSettingsJSON(sp("extension_id"))
	case "getLyricsFetchOptionsJSON":
		return gobackend.GetLyricsFetchOptionsJSON()
	case "getLyricsProvidersJSON":
		return gobackend.GetLyricsProvidersJSON()
	case "getMetadataProviderPriorityJSON":
		return gobackend.GetMetadataProviderPriorityJSON()
	case "getProviderPriorityJSON":
		return gobackend.GetProviderPriorityJSON()
	case "getStoreCategoriesJSON":
		return gobackend.GetStoreCategoriesJSON()
	case "getStoreExtensionsJSON":
		return gobackend.GetStoreExtensionsJSON(bd("force_refresh"))
	case "getStoreRegistryURLJSON":
		return gobackend.GetStoreRegistryURLJSON()
	case "searchStoreExtensionsJSON":
		return gobackend.SearchStoreExtensionsJSON(sp("query"), sp("category"))
	case "setDownloadFallbackExtensionIdsJSON":
		return "ok", gobackend.SetExtensionFallbackProviderIDsJSON(sp("extension_ids"))
	case "setExtensionSettingsJSON":
		return "ok", gobackend.SetExtensionSettingsJSON(sp("extension_id"), sp("settings"))
	case "setLyricsFetchOptionsJSON":
		return "ok", gobackend.SetLyricsFetchOptionsJSON(sp("options_json"))
	case "setLyricsProvidersJSON":
		return "ok", gobackend.SetLyricsProvidersJSON(sp("providers_json"))
	case "setMetadataProviderPriorityJSON":
		return "ok", gobackend.SetMetadataProviderPriorityJSON(sp("priority"))
	case "setProviderPriorityJSON":
		return "ok", gobackend.SetProviderPriorityJSON(sp("priority"))
	case "setStoreRegistryURLJSON":
		return "ok", gobackend.SetStoreRegistryURLJSON(sp("registry_url"))
	case "scanSafTreeIncremental":
		return gobackend.ScanLibraryFolderIncrementalJSON(sp("tree_uri"), sp("existing_files"))
	case "scanSafTreeIncrementalFromSnapshot":
		return gobackend.ScanLibraryFolderIncrementalFromSnapshotJSON(sp("tree_uri"), sp("snapshot_path"))
	case "searchTracksWithExtensions":
		result, err := gobackend.SearchTracksWithMetadataProvidersJSON(sp("query"), sn("limit"), true)
		if err != nil || result == "[]" || result == "null" {
			return searchWithDeezer(sp("query"), sn("limit"))
		}
		return result, err

	default:
		return nil, fmt.Errorf("unknown method: %s", method)
	}
}
