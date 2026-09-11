package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	backend "github.com/zarz/bitly/go_backend/internal/gobackend"
)

func main() {
	log.SetFlags(log.LstdFlags)

	// Modo PWA/web: el servidor sirve archivos estáticos de Flutter web
	// y la API de música. Se activa con --web o WEB_MODE=1.
	webMode := false
	for _, arg := range os.Args[1:] {
		if arg == "--web" || arg == "-web" {
			webMode = true
		}
	}
	if os.Getenv("WEB_MODE") == "1" {
		webMode = true
	}

	// Si el padre (bitly.exe) muere, el backend debe salir solo: en PC la app
	// y el backend son procesos separados y al cerrar la ventana no quedan
	// huérfanos ocupando el puerto/RAM. Se vigila el PID del padre cada 2s.
	// vigilarPadre está implementado por plataforma (watchdog_windows.go con
	// OpenProcess, watchdog_other.go con Signal(0)).
	if !webMode && len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil && v > 0 {
			vigilarPadre(v)
		}
	}

	result := backend.InitGlobalState()
	if strings.Contains(result, `"error"`) {
		log.Fatalf("[server] Init failed: %s", result)
	}
	log.Printf("[server] Ready: %s", result)

	port := os.Getenv("PORT")
	if port == "" {
		if webMode {
			port = "8080"
		} else {
			port = "55009"
		}
	}

	mux := http.NewServeMux()
	registerAllRoutes(mux)

	// En modo web, servir archivos estáticos de Flutter web.
	// La app Flutter web vive en ./web/ (o el path en WEB_DIR).
	if webMode {
		webDir := os.Getenv("WEB_DIR")
		if webDir == "" {
			webDir = "web"
		}
		serveFlutterWeb(mux, webDir)
		log.Printf("[server] Modo PWA activo — sirviendo archivos de %s", webDir)
	}

	// En modo web escucha en 0.0.0.0 (aceptar conexiones externas).
	// En modo local sigue en 127.0.0.1.
	host := "127.0.0.1"
	if webMode {
		host = "0.0.0.0"
	}

	addr := fmt.Sprintf("%s:%s", host, port)
	server := &http.Server{Addr: addr, Handler: corsMiddleware(mux)}

	go func() {
		log.Printf("🌐 Go backend server listening on http://%s", addr)
		if webMode {
			log.Printf("   PWA: abre http://%s en Safari/Chrome", addr)
		} else {
			log.Printf("   Try: curl http://127.0.0.1:%s/ping", port)
			log.Printf("   Try: curl \"http://127.0.0.1:%s/search/tracks?q=queen\"", port)
		}
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[server] Error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("[server] Shutting down")
}

// serveFlutterWeb registra un handler que sirve archivos estáticos de
// Flutter web. Maneja SPA routing: cualquier ruta que no sea /api/*
// devuelve index.html para que Flutter maneje la navegación.
func serveFlutterWeb(mux *http.ServeMux, webDir string) {
	// Resolver el path absoluto
	absDir, err := filepath.Abs(webDir)
	if err != nil {
		log.Printf("[server] WARN: no se pudo resolver WEB_DIR=%s: %v", webDir, err)
		absDir = webDir
	}

	// Servidor de archivos estáticos
	fs := http.FileServer(http.Dir(absDir))

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path

		// Las rutas de API las maneja el mux normalmente
		if strings.HasPrefix(path, "/api/") || strings.HasPrefix(path, "/search") ||
			strings.HasPrefix(path, "/stream") || strings.HasPrefix(path, "/cover") ||
			strings.HasPrefix(path, "/download") || strings.HasPrefix(path, "/feed") ||
			strings.HasPrefix(path, "/ping") || strings.HasPrefix(path, "/rpc") ||
			path == "/health" || path == "/extensions" {
			// No interceptar — dejar que otras rutas del mux respondan
			http.NotFound(w, r)
			return
		}

		// Si el archivo existe, servirlo
		filePath := filepath.Join(absDir, path)
		if info, err := os.Stat(filePath); err == nil && !info.IsDir() {
			fs.ServeHTTP(w, r)
			return
		}

		// SPA fallback: devolver index.html para rutas de Flutter
		http.ServeFile(w, r, filepath.Join(absDir, "index.html"))
	})
}
