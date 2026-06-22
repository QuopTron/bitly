package store

import (
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manager"
)

type storeExtensionResponse struct {
	ID               string   `json:"id"`
	Name             string   `json:"name"`
	DisplayName      string   `json:"display_name"`
	Version          string   `json:"version"`
	Description      string   `json:"description"`
	DownloadURL      string   `json:"download_url"`
	IconURL          string   `json:"icon_url,omitempty"`
	Category         string   `json:"category"`
	Tags             []string `json:"tags,omitempty"`
	Downloads        int      `json:"downloads"`
	UpdatedAt        string   `json:"updated_at"`
	MinAppVersion    string   `json:"min_app_version,omitempty"`
	IsInstalled      bool     `json:"is_installed"`
	InstalledVersion string   `json:"installed_version,omitempty"`
	HasUpdate        bool     `json:"has_update"`
}

func (e *storeExtension) toResponse() storeExtensionResponse {
	resp := storeExtensionResponse{
		ID:            e.ID,
		Name:          e.Name,
		DisplayName:   e.getDisplayName(),
		Version:       e.Version,
		Description:   e.Description,
		DownloadURL:   e.getDownloadURL(),
		IconURL:       e.getIconURL(),
		Category:      e.Category,
		Downloads:     e.Downloads,
		UpdatedAt:     e.UpdatedAt,
		MinAppVersion: e.getMinAppVersion(),
	}
	if len(e.Tags) > 0 {
		resp.Tags = append([]string(nil), e.Tags...)
	}
	return resp
}

type Store struct {
	manager     *manager.Manager
	registryURL string
	cacheDir    string
	mu          sync.RWMutex
	cache       *storeRegistry
	cacheTime   time.Time
	cacheTTL    time.Duration
}

func New(mgr *manager.Manager, cacheDir string) *Store {
	s := &Store{
		manager:     mgr,
		registryURL: DefaultRegistryURL,
		cacheDir:    cacheDir,
		cacheTTL:    cacheTTL,
	}
	s.loadDiskCache()
	return s
}
