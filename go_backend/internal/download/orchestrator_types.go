package download

import (
	"sync"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Request representa una solicitud de descarga desde Flutter.
// El payload de strategy usa claves snake_case; DownloadByStrategy las mapea.
type Request struct {
	ItemID    string `json:"itemId"`
	Title     string `json:"title"`
	Artist    string `json:"artist"`
	Album     string `json:"album"`
	ISRC      string `json:"isrc"`
	Provider  string `json:"provider"`
	TrackID   string `json:"trackId"`
	Quality   string `json:"quality"`
	OutputDir string `json:"outputDir"`
	Type      string `json:"type"`
	LyricsSrc string `json:"source"`
	// IDs cross-provider (opcionales) para un matching de respaldo mas rico,
	// espejo de los inputs CheckAvailabilityForItemID del middleware de referencia.
	SpotifyID  string `json:"spotifyId,omitempty"`
	DeezerID   string `json:"deezerId,omitempty"`
	TidalID    string `json:"tidalId,omitempty"`
	QobuzID    string `json:"qobuzId,omitempty"`
	DurationMS int    `json:"durationMs,omitempty"`
}

// Result holds the outcome of a download.
type Result struct {
	ItemID    string `json:"itemId"`
	Success   bool   `json:"success"`
	Provider  string `json:"provider,omitempty"`
	StreamURL string `json:"streamUrl,omitempty"`
	FilePath  string `json:"filePath,omitempty"`
	Encrypted bool   `json:"encrypted,omitempty"`
	Error     string `json:"error,omitempty"`
	// ClientDecrypt is set when the provider handed back an encrypted/DRM file
	// with a decryption key but no CLI ffmpeg is available on this platform
	// (e.g. Android). The file is kept on disk so the client can decrypt it
	// (e.g. via ffmpeg-kit) and then play it.
	ClientDecrypt   bool   `json:"clientDecrypt,omitempty"`
	DecryptionKey   string `json:"decryptionKey,omitempty"`
	OutputExtension string `json:"outputExtension,omitempty"`
	InputFormat     string `json:"inputFormat,omitempty"`
	// ErrorType classifies failures (e.g. "verification_required") so the
	// client can react (open a Cloudflare challenge) instead of failing blindly.
	ErrorType string `json:"errorType,omitempty"`
	// Service names the provider involved in an error (e.g. which one needs
	// verification), mirroring the reference middleware's "Service" field.
	Service string `json:"service,omitempty"`
}

// Orchestrator gestiona las descargas con respaldo entre proveedores.
// Un proveedor puede exponer un descarga() JS completa (extensiones) o una
// URL de stream (proveedores nativos). En ambos casos el audio se escribe a
// disco para que Flutter pueda reproducir el archivo local y persistirlo.
type Orchestrator struct {
	providers     *provider.Registry
	tracker       *Tracker
	mu            sync.Mutex
	active        map[string]bool
	fallbackOrder []string
	// priorityOrder is the user-configurable provider preference (best-first),
	// mirroring SpotiFLAC's SetProviderPriority. Empty means the built-in
	// default [preferredStreamOrder]. Rebuilt into fallbackOrder on set.
	priorityOrder []string
	concurrency   chan struct{}
}
