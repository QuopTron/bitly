package bundled_extensions

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
	// IsDownloadProvider es true cuando el manifest lista una capacidad de
	// descarga. Sirve para omitir extensiones solo-metadata (p. ej. spotify-web)
	// durante el streaming/descarga de respaldo.
	IsDownloadProvider bool `json:"isDownloadProvider,omitempty"`
	// QualityOptions mirrors manifest.qualityOptions (id list), so the
	// fallback can pick a quality token each extension recognizes.
	QualityOptions []string `json:"qualityOptions,omitempty"`
	// QualityTiers mirrors the full manifest qualityOptions entries (id +
	// optional label + per-tier credential settings). SpotiFLAC's
	// qualitySettings concept: a Hi-Res tier may need its own API key/endpoint
	// settings that lower tiers don't. Exposed so UI/store surfaces can render
	// per-quality credential fields.
	QualityTiers []QualityTier `json:"qualityTiers,omitempty"`
	// Search mirrors the manifest's searchBehavior block. It's how the
	// extension declares its search category bubbles (id/label/icon) and
	// thumbnail ratio — the source of truth for the search UI, same as
	// SpotiFLAC reads it from the manifest.
	Search Search `json:"searchBehavior,omitempty"`
}

// QualityTier is one quality entry from the manifest qualityOptions array,
// optionally carrying per-tier credential settings (SpotiFLAC qualitySettings).
type QualityTier struct {
	ID       string           `json:"id"`
	Label    string           `json:"label,omitempty"`
	Settings []QualitySetting `json:"settings,omitempty"`
}

// QualitySetting is a credential/option a single quality tier requires
// (e.g. a Hi-Res tier that needs its own apiKey). Type mirrors the setting
// types (string/number/boolean/select).
type QualitySetting struct {
	Key     string   `json:"key"`
	Label   string   `json:"label,omitempty"`
	Hint    string   `json:"hint,omitempty"`
	Type    string   `json:"type,omitempty"`
	Default string   `json:"default,omitempty"`
	Options []string `json:"options,omitempty"`
}

// SearchFilter describes a single search category bubble from the manifest.
type SearchFilter struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Icon  string `json:"icon"`
}

// Search mirrors manifest.searchBehavior for the search UI.
type Search struct {
	Enabled bool `json:"enabled,omitempty"`
	// Primary marks the extension as the default search source (SpotiFLAC's
	// defaultSearchExtension): the search UI selects it first and the backend
	// tries it before any other source when searching "Todas".
	Primary        bool           `json:"primary,omitempty"`
	Placeholder    string         `json:"placeholder,omitempty"`
	ThumbnailRatio string         `json:"thumbnailRatio,omitempty"`
	Filters        []SearchFilter `json:"filters,omitempty"`
}

// LoadAllToRegistry loads all bundled extensions into the provided registry
// and returns the list of successfully registered extensions.
