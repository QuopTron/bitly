package bundled_extensions

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// RegisteredExtension holds info about a successfully loaded bundled extension.
type RegisteredExtension struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Version string `json:"version"`
	Type    string `json:"type"` // "metadata", "download", "both"
	Enabled bool   `json:"enabled"`
	// Replaces lists built-in provider names this extension supersedes
	// (from the manifest's "replacesBuiltInProviders"). Used to avoid
	// registering both a native provider and its -web extension.
	Replaces []string `json:"replaces,omitempty"`
	// HasHomeFeed mirrors the manifest's capabilities.homeFeed flag —
	// whether the extension can produce a home feed (like SpotiFLAC's
	// hasHomeFeed). Used to avoid attempting feeds from sources that
	// don't provide one.
	HasHomeFeed bool `json:"hasHomeFeed,omitempty"`
	// IsDownloadProvider is true when the manifest lists a download
	// capability. Used to skip metadata-only extensions (e.g. spotify-web)
	// during the streaming/download fallback.
	IsDownloadProvider bool `json:"isDownloadProvider,omitempty"`
	// QualityOptions mirrors manifest.qualityOptions (id list), so the
	// fallback can pick a quality token each extension recognizes.
	QualityOptions []string `json:"qualityOptions,omitempty"`
	// Search mirrors the manifest's searchBehavior block. It's how the
	// extension declares its search category bubbles (id/label/icon) and
	// thumbnail ratio — the source of truth for the search UI, same as
	// SpotiFLAC reads it from the manifest.
	Search Search `json:"searchBehavior,omitempty"`
}

// SearchFilter describes a single search category bubble from the manifest.
type SearchFilter struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Icon  string `json:"icon"`
}

// Search mirrors manifest.searchBehavior for the search UI.
type Search struct {
	Enabled        bool           `json:"enabled,omitempty"`
	Placeholder    string         `json:"placeholder,omitempty"`
	ThumbnailRatio string         `json:"thumbnailRatio,omitempty"`
	Filters        []SearchFilter `json:"filters,omitempty"`
}

// LoadAllToRegistry loads all bundled extensions into the provided registry
// and returns the list of successfully registered extensions.
func LoadAllToRegistry(reg *extensions.Registry) []RegisteredExtension {
	dirs, err := List()
	if err != nil {
		return nil
	}

	list := make([]RegisteredExtension, 0, len(dirs))
	cfg := extensions.DefaultConfig()
	cfg.EnableFS = true
	cfg.AllowedDirs = []string{"."}

	for _, dir := range dirs {
		ext, err := Load(dir)
		if err != nil {
			continue
		}

		// Parse manifest for metadata
		var manifest struct {
			Name           string                          `json:"name"`
			DisplayName    string                          `json:"displayName"`
			Version        string                          `json:"version"`
		Type           []string                        `json:"type"`
		SignedSession  *extensions.SignedSessionConfig `json:"signedSession,omitempty"`
		RequiredFeats  []string                        `json:"requiredRuntimeFeatures,omitempty"`
		Capabilities   struct {
			Replaces []string `json:"replacesBuiltInProviders"`
			HomeFeed bool     `json:"homeFeed"`
		} `json:"capabilities"`
		QualityOptions []struct {
			ID string `json:"id"`
		} `json:"qualityOptions"`
		SearchBehavior struct {
				Enabled        bool   `json:"enabled"`
				Placeholder    string `json:"placeholder"`
				ThumbnailRatio string `json:"thumbnailRatio"`
				Filters        []SearchFilter
			} `json:"searchBehavior"`
		}
		if err := json.Unmarshal(ext.ManifestData, &manifest); err != nil {
			manifest.Name = dir
			manifest.Version = "0.0.0"
		}
		if manifest.Name == "" {
			manifest.Name = dir
		}

		extType := "both"
		if len(manifest.Type) == 1 {
			extType = manifest.Type[0]
		} else if len(manifest.Type) == 0 {
			extType = "metadata"
		}

		// A provider can download only if its manifest lists a download
		// capability (metadata_provider/lyrics_provider alone cannot).
		isDownload := false
		for _, t := range manifest.Type {
			if t == "download_provider" {
				isDownload = true
				break
			}
		}
		qOpts := make([]string, 0, len(manifest.QualityOptions))
		for _, q := range manifest.QualityOptions {
			if q.ID != "" {
				qOpts = append(qOpts, q.ID)
			}
		}

		// Run the extension JS in sandbox
		_, err = reg.Runtime().RunJS(
			string(ext.IndexJSData),
			dir,
			manifest.Name,
			cfg,
			".",
		)
		if err != nil {
			_ = err // silently skip failed extensions
			continue
		}

		// Attach signed session config from manifest to the sandbox.
		if sb := reg.Runtime().Sandbox(dir); sb != nil && manifest.SignedSession != nil {
			sb.SignedSession = manifest.SignedSession
			sb.Session = &extensions.SignedSessionState{}
		}

		list = append(list, RegisteredExtension{
			ID:          dir,
			Name:        manifest.DisplayName,
			Version:     manifest.Version,
			Type:        extType,
			Enabled:     true,
			Replaces:    manifest.Capabilities.Replaces,
			HasHomeFeed: manifest.Capabilities.HomeFeed,
			IsDownloadProvider: isDownload,
			QualityOptions:     qOpts,
			Search: Search{
				Enabled:        manifest.SearchBehavior.Enabled,
				Placeholder:    manifest.SearchBehavior.Placeholder,
				ThumbnailRatio: manifest.SearchBehavior.ThumbnailRatio,
				Filters:        manifest.SearchBehavior.Filters,
			},
		})
	}

	return list
}

// LoadByName loads a specific bundled extension by name into the registry.
func LoadByName(reg *extensions.Registry, name string) (*RegisteredExtension, error) {
	ext, err := Load(name)
	if err != nil {
		return nil, fmt.Errorf("bundled extension %s not found: %w", name, err)
	}

	var manifest struct {
		Name        string   `json:"name"`
		DisplayName string   `json:"displayName"`
		Version     string   `json:"version"`
		Type        []string `json:"type"`
	}
	if err := json.Unmarshal(ext.ManifestData, &manifest); err != nil {
		manifest.Name = name
		manifest.Version = "0.0.0"
	}
	if manifest.Name == "" {
		manifest.Name = name
	}

	cfg := extensions.DefaultConfig()
	cfg.EnableFS = true

	_, err = reg.Runtime().RunJS(
		string(ext.IndexJSData),
		name,
		manifest.Name,
		cfg,
		".",
	)
	if err != nil {
		return nil, fmt.Errorf("run bundled %s: %w", name, err)
	}

	extType := "both"
	if len(manifest.Type) == 1 {
		extType = manifest.Type[0]
	}

	return &RegisteredExtension{
		ID:      name,
		Name:    manifest.DisplayName,
		Version: manifest.Version,
		Type:    extType,
		Enabled: true,
	}, nil
}
