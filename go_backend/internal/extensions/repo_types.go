package extensions

import (
	"net/http"
	"sync"
	"time"
)

const (
	maxPackageSize = 64 * 1024 * 1024 // 64 MiB limit
	repoCacheTTL   = 30 * time.Minute
	sha256HexSize  = 64
)

// RepoExtension represents an extension in the remote registry.
type RepoExtension struct {
	ID            string   `json:"id"`
	Name          string   `json:"name"`
	DisplayName   string   `json:"display_name"`
	Description   string   `json:"description"`
	Version       string   `json:"version"`
	Author        string   `json:"author"`
	Category      string   `json:"category"` // metadata, download, utility, lyrics, integration
	DownloadURL   string   `json:"download_url"`
	SHA256        string   `json:"sha256"`
	SizeBytes     int64    `json:"size_bytes"`
	ScreenshotURL string   `json:"screenshot_url,omitempty"`
	Tags          []string `json:"tags,omitempty"`
}

// RepoCategory represents a category of extensions.
type RepoCategory struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Count       int    `json:"count"`
}

// RepoRegistry holds the remote extension registry data.
type RepoRegistry struct {
	Extensions []RepoExtension `json:"extensions"`
	Categories []RepoCategory  `json:"categories"`
	Version    string          `json:"version"`
	UpdatedAt  time.Time       `json:"updated_at"`
}

// ExtensionStore manages the extension repository.
type ExtensionStore struct {
	mu            sync.RWMutex
	registryURL   string
	cache         *RepoRegistry
	cacheExpiry   time.Time
	httpClient    *http.Client
	extensionsDir string
	dataDir       string
	installed     map[string]string // id → version
}

// NewExtensionStore creates a new extension store.
