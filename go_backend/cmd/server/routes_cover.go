package main

import (
	"net/http"
	"path/filepath"
	"strings"

	backend "github.com/zarz/bitly/go_backend"
)

// registerCoverRoute serves cached cover images under /cover/<filename>.
// Files are served from the same directory the backend SaveCover writes to.
func registerCoverRoute(mux *http.ServeMux) {
	mux.HandleFunc("/cover/", func(w http.ResponseWriter, r *http.Request) {
		filename := strings.TrimPrefix(r.URL.Path, "/cover/")
		if filename == "" || strings.Contains(filename, "..") || strings.ContainsAny(filename, "/\\") {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		dir := backend.CoversDir()
		path := filepath.Join(dir, filepath.Base(filename))
		http.ServeFile(w, r, path)
	})
}
