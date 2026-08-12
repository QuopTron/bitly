package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
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
