package store

import "time"

const (
	CategoryMetadata    = "metadata"
	CategoryDownload    = "download"
	CategoryUtility     = "utility"
	CategoryLyrics      = "lyrics"
	CategoryIntegration = "integration"

	cacheTTL           = 30 * time.Minute
	cacheFileName      = "store_cache.json"
	DefaultRegistryURL = "https://raw.githubusercontent.com/QuopTron/bitly-extensions/main/registry.json"
	downloadTimeout    = 5 * time.Minute
	registryTimeout    = 30 * time.Second
	githubAPITimeout   = 10 * time.Second
)

type storeExtension struct {
	ID               string   `json:"id"`
	Name             string   `json:"name"`
	DisplayName      string   `json:"display_name,omitempty"`
	Version          string   `json:"version"`
	Description      string   `json:"description"`
	DownloadURL      string   `json:"download_url,omitempty"`
	IconURL          string   `json:"icon_url,omitempty"`
	Category         string   `json:"category"`
	Tags             []string `json:"tags,omitempty"`
	Downloads        int      `json:"downloads"`
	UpdatedAt        string   `json:"updated_at"`
	MinAppVersion    string   `json:"min_app_version,omitempty"`
	DisplayNameAlt   string   `json:"displayName,omitempty"`
	DownloadURLAlt   string   `json:"downloadUrl,omitempty"`
	IconURLAlt       string   `json:"iconUrl,omitempty"`
	MinAppVersionAlt string   `json:"minAppVersion,omitempty"`
}

func (e *storeExtension) getDisplayName() string {
	if e.DisplayName != "" {
		return e.DisplayName
	}
	if e.DisplayNameAlt != "" {
		return e.DisplayNameAlt
	}
	return e.Name
}

func (e *storeExtension) getDownloadURL() string {
	if e.DownloadURL != "" {
		return e.DownloadURL
	}
	return e.DownloadURLAlt
}

func (e *storeExtension) getIconURL() string {
	if e.IconURL != "" {
		return e.IconURL
	}
	return e.IconURLAlt
}

func (e *storeExtension) getMinAppVersion() string {
	if e.MinAppVersion != "" {
		return e.MinAppVersion
	}
	return e.MinAppVersionAlt
}

type storeRegistry struct {
	Version    int              `json:"version"`
	UpdatedAt  string           `json:"updated_at"`
	Extensions []storeExtension `json:"extensions"`
}
