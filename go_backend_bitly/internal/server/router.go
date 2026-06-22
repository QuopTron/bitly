package server

import (
	"encoding/json"
	"net/http"
)

// Router handles HTTP route registration.
type Router struct {
	mux *http.ServeMux
}

// NewRouter creates a new router.
func NewRouter() *Router {
	return &Router{mux: http.NewServeMux()}
}

// Handle registers an HTTP handler for a pattern.
func (r *Router) Handle(pattern string, handler http.HandlerFunc) {
	r.mux.HandleFunc(pattern, handler)
}

// Mux returns the underlying ServeMux.
func (r *Router) Mux() *http.ServeMux {
	return r.mux
}

// JSON writes a JSON response.
func JSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

// Error writes a JSON error response.
func Error(w http.ResponseWriter, status int, msg string) {
	JSON(w, status, map[string]string{"error": msg})
}
