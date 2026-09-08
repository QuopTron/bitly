package bundled_extensions

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

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
			Name          string                          `json:"name"`
			DisplayName   string                          `json:"displayName"`
			Version       string                          `json:"version"`
			Type          []string                        `json:"type"`
			SignedSession *extensions.SignedSessionConfig `json:"signedSession,omitempty"`
			RequiredFeats []string                        `json:"requiredRuntimeFeatures,omitempty"`
			Capabilities  struct {
				Replaces []string `json:"replacesBuiltInProviders"`
				HomeFeed bool     `json:"homeFeed"`
			} `json:"capabilities"`
			QualityOptions []struct {
				ID       string `json:"id"`
				Label    string `json:"label"`
				Settings []struct {
					Key     string   `json:"key"`
					Label   string   `json:"label"`
					Hint    string   `json:"hint"`
					Type    string   `json:"type"`
					Default string   `json:"default"`
					Options []string `json:"options"`
				} `json:"settings"`
			} `json:"qualityOptions"`
			SearchBehavior struct {
				Enabled        bool   `json:"enabled"`
				Primary        bool   `json:"primary"`
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

		// Un proveedor puede descarga solo si su manifest listas un descarga
		// capability (metadata_provider/lyrics_provider alone cannot).
		isDownload := false
		for _, t := range manifest.Type {
			if t == "download_provider" {
				isDownload = true
				break
			}
		}
		qOpts := make([]string, 0, len(manifest.QualityOptions))
		qTiers := make([]QualityTier, 0, len(manifest.QualityOptions))
		for _, q := range manifest.QualityOptions {
			if q.ID == "" {
				continue
			}
			qOpts = append(qOpts, q.ID)
			tier := QualityTier{ID: q.ID, Label: q.Label}
			for _, s := range q.Settings {
				if s.Key == "" {
					continue
				}
				tier.Settings = append(tier.Settings, QualitySetting{
					Key: s.Key, Label: s.Label, Hint: s.Hint,
					Type: s.Type, Default: s.Default, Options: s.Options,
				})
			}
			qTiers = append(qTiers, tier)
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
			ID:                 dir,
			Name:               manifest.DisplayName,
			Version:            manifest.Version,
			Type:               extType,
			Enabled:            true,
			Replaces:           manifest.Capabilities.Replaces,
			HasHomeFeed:        manifest.Capabilities.HomeFeed,
			IsDownloadProvider: isDownload,
			QualityOptions:     qOpts,
			QualityTiers:       qTiers,
			Search: Search{
				Enabled:        manifest.SearchBehavior.Enabled,
				Primary:        manifest.SearchBehavior.Primary,
				Placeholder:    manifest.SearchBehavior.Placeholder,
				ThumbnailRatio: manifest.SearchBehavior.ThumbnailRatio,
				Filters:        manifest.SearchBehavior.Filters,
			},
		})
	}

	return list
}

// LoadByName loads a specific bundled extension by name into the registry.
