package main

import (
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	"github.com/zarz/bitly/go_backend_bitly/internal/server"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc/handlers"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

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

	dbPath := os.Getenv("DB_PATH")
	if dbPath == "" {
		dbPath = "bitly.db"
	}
	if err := database.Init(dbPath); err != nil {
		log.Fatalf("[DB] Init failed: %v", err)
	}
	defer database.Close()

	if runtime.GOOS == "windows" {
		go ensureFFmpeg()
	}

	dispatcher := rpc.NewDispatcher()
	handlers.RegisterSystemHandlers(dispatcher.Registry)
	handlers.RegisterPremiumHandlers(dispatcher.Registry)
	handlers.RegisterMetadataHandlers(dispatcher.Registry)
	handlers.RegisterSearchHandlers(dispatcher.Registry)
	handlers.RegisterDownloadHandlers(dispatcher.Registry)
	handlers.RegisterPlaybackHandlers(dispatcher.Registry)
	handlers.RegisterLibraryHandlers(dispatcher.Registry)
	handlers.RegisterLyricsHandlers(dispatcher.Registry)
	handlers.RegisterVideoHandlers(dispatcher.Registry)
	handlers.RegisterScrobblingHandlers(dispatcher.Registry)
	handlers.RegisterAvailabilityHandlers(dispatcher.Registry)
	handlers.RegisterAvailabilityDeezerExtra(dispatcher.Registry)
	handlers.RegisterExtensionHandlers(dispatcher.Registry)
	handlers.RegisterV2Handlers(dispatcher.Registry)
	handlers.RegisterStatsHandlers(dispatcher.Registry)
	handlers.RegisterSecretsHandlers(dispatcher.Registry)
	handlers.RegisterNormalizationHandlers(dispatcher.Registry)
	handlers.RegisterPlaylistHandlers(dispatcher.Registry)
	handlers.RegisterUpdateHandlers(dispatcher.Registry)
	handlers.RegisterMiscHandlers(dispatcher.Registry)
	handlers.RegisterPostProcessingHandlers(dispatcher.Registry)
	handlers.RegisterCueSheetHandlers(dispatcher.Registry)
	handlers.RegisterDuplicateHandlers(dispatcher.Registry)

	router := server.NewRouter()
	router.Handle("/", handleIndex)
	router.Handle("/rpc", dispatcher.ServeHTTP)

	handler := server.ApplyMiddleware(router.Mux(), server.Logger, server.CORS)

	addr := "127.0.0.1:" + port
	log.Printf("[bitly-backend] Backend v3.0.0 on %s", addr)
	log.Fatal(http.ListenAndServe(addr, handler))
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	server.JSON(w, http.StatusOK, map[string]interface{}{
		"servicio": "bitly-backend",
		"version":  "3.0.0",
		"status":   "ok",
	})
}
