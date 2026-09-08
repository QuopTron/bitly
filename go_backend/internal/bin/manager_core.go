package bin

import (
	"net/http"
	"time"
)

// Binary describe un binario externo con su plataforma y URL de descarga.
type Binary struct {
	Name     string `json:"name"`
	Version  string `json:"version"`
	Path     string `json:"path"`
	URL      string `json:"url"`
	Platform string `json:"platform"`
}

// Manager gestiona la descarga de binarios externos (yt-dlp, ffmpeg) con detección de arquitectura.
type Manager struct {
	dirBin string
	http   *http.Client
}

// NewManager crea un gestor de binarios en el directorio dado.
func NewManager(binDir string) *Manager {
	return &Manager{
		dirBin: binDir,
		http:   &http.Client{Timeout: 10 * time.Minute},
	}
}
