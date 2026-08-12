package main

import (
	"fmt"
	"net/http"
)

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
