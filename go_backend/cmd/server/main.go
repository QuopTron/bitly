package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"

	backend "github.com/zarz/bitly/go_backend/internal/gobackend"
)

func main() {
	log.SetFlags(log.LstdFlags)

	// Si el padre (bitly.exe) muere, el backend debe salir solo: en PC la app
	// y el backend son procesos separados y al cerrar la ventana no quedan
	// huérfanos ocupando el puerto/RAM. Se vigila el PID del padre cada 2s.
	// vigilarPadre está implementado por plataforma (watchdog_windows.go con
	// OpenProcess, watchdog_other.go con Signal(0)).
	if len(os.Args) > 1 {
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
		port = "55009"
	}

	mux := http.NewServeMux()
	registerAllRoutes(mux)

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
