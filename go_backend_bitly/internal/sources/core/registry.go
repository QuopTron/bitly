package core

import "sync"

// SearchResultItem is a unified search result item from any provider.
type SearchResultItem struct {
	ID       string `json:"id"`
	Title    string `json:"title"`
	Artist   string `json:"artist"`
	Album    string `json:"album,omitempty"`
	Duration int64  `json:"duration_ms"`
	ISRC     string `json:"isrc,omitempty"`
	Source   string `json:"source"`
	CoverURL string `json:"cover_url,omitempty"`
}

// SearchProvider defines the interface for search-capable providers.
type SearchProvider interface {
	ID() string
	Name() string
	Search(query string, limit int) ([]SearchResultItem, error)
}

// DownloadProvider defines the interface for download-capable providers.
type DownloadProvider interface {
	ID() string
	Name() string
	Download(trackID, quality string) ([]byte, error)
}

// MetadataProvider defines the interface for metadata providers.
type MetadataProvider interface {
	ID() string
	Name() string
	GetTrackMetadata(providerTrackID string) (interface{}, error)
	GetAlbumMetadata(providerAlbumID string) (interface{}, error)
}

// LyricsProvider defines the interface for lyrics providers.
type LyricsProvider interface {
	ID() string
	Name() string
	FetchLyrics(trackName, artistName string, durationSec float64) (interface{}, error)
}

// ProviderRegistry registers and manages all sources.
type ProviderRegistry struct {
	mu                 sync.RWMutex
	searchProviders    map[string]SearchProvider
	downloadProviders  map[string]DownloadProvider
	metadataProviders  map[string]MetadataProvider
	lyricsProviders    map[string]LyricsProvider
}

// NewProviderRegistry creates an empty registry.
func NewProviderRegistry() *ProviderRegistry {
	return &ProviderRegistry{
		searchProviders:   make(map[string]SearchProvider),
		downloadProviders: make(map[string]DownloadProvider),
		metadataProviders: make(map[string]MetadataProvider),
		lyricsProviders:   make(map[string]LyricsProvider),
	}
}

func (r *ProviderRegistry) RegisterSearchProvider(id string, p SearchProvider) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.searchProviders[id] = p
}

func (r *ProviderRegistry) RegisterDownloadProvider(id string, p DownloadProvider) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.downloadProviders[id] = p
}

func (r *ProviderRegistry) RegisterMetadataProvider(id string, p MetadataProvider) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.metadataProviders[id] = p
}

func (r *ProviderRegistry) RegisterLyricsProvider(id string, p LyricsProvider) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.lyricsProviders[id] = p
}

func (r *ProviderRegistry) GetSearchProvider(id string) SearchProvider {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.searchProviders[id]
}

func (r *ProviderRegistry) GetDownloadProvider(id string) DownloadProvider {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.downloadProviders[id]
}

func (r *ProviderRegistry) GetAllSearchProviders() []SearchProvider {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]SearchProvider, 0, len(r.searchProviders))
	for _, p := range r.searchProviders {
		result = append(result, p)
	}
	return result
}

func (r *ProviderRegistry) GetAllDownloadProviders() []DownloadProvider {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]DownloadProvider, 0, len(r.downloadProviders))
	for _, p := range r.downloadProviders {
		result = append(result, p)
	}
	return result
}
