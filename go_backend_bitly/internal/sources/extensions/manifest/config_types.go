package manifest

type ExtensionPermissions struct {
	Network   []string `json:"network"`
	Storage   bool     `json:"storage"`
	File      bool     `json:"file"`
	AllowHTTP bool     `json:"allowHttp,omitempty"`
}

type ExtensionSetting struct {
	Key         string      `json:"key"`
	Type        SettingType `json:"type"`
	Label       string      `json:"label"`
	Description string      `json:"description,omitempty"`
	Required    bool        `json:"required,omitempty"`
	Secret      bool        `json:"secret,omitempty"`
	Default     interface{} `json:"default,omitempty"`
	Options     []string    `json:"options,omitempty"`
	Action      string      `json:"action,omitempty"`
}

type QualityOption struct {
	ID          string                   `json:"id"`
	Label       string                   `json:"label"`
	Description string                   `json:"description"`
	Settings    []QualitySpecificSetting `json:"settings,omitempty"`
}

type QualitySpecificSetting struct {
	Key         string      `json:"key"`
	Type        SettingType `json:"type"`
	Label       string      `json:"label"`
	Description string      `json:"description,omitempty"`
	Required    bool        `json:"required,omitempty"`
	Secret      bool        `json:"secret,omitempty"`
	Default     interface{} `json:"default,omitempty"`
	Options     []string    `json:"options,omitempty"`
}

type SearchFilter struct {
	ID    string `json:"id"`
	Label string `json:"label,omitempty"`
	Icon  string `json:"icon,omitempty"`
}

type SearchBehaviorConfig struct {
	Enabled         bool           `json:"enabled"`
	Placeholder     string         `json:"placeholder,omitempty"`
	Primary         bool           `json:"primary,omitempty"`
	Icon            string         `json:"icon,omitempty"`
	ThumbnailRatio  string         `json:"thumbnailRatio,omitempty"`
	ThumbnailWidth  int            `json:"thumbnailWidth,omitempty"`
	ThumbnailHeight int            `json:"thumbnailHeight,omitempty"`
	Filters         []SearchFilter `json:"filters,omitempty"`
}

type URLHandlerConfig struct {
	Enabled  bool     `json:"enabled"`
	Patterns []string `json:"patterns,omitempty"`
}

type TrackMatchingConfig struct {
	CustomMatching    bool   `json:"customMatching"`
	Strategy          string `json:"strategy,omitempty"`
	DurationTolerance int    `json:"durationTolerance,omitempty"`
}

type PostProcessingHook struct {
	ID               string   `json:"id"`
	Name             string   `json:"name"`
	Description      string   `json:"description,omitempty"`
	DefaultEnabled   bool     `json:"defaultEnabled,omitempty"`
	SupportedFormats []string `json:"supportedFormats,omitempty"`
}

type PostProcessingConfig struct {
	Enabled bool                 `json:"enabled"`
	Hooks   []PostProcessingHook `json:"hooks,omitempty"`
}

type ExtensionHealthCheck struct {
	ID              string `json:"id"`
	Label           string `json:"label,omitempty"`
	URL             string `json:"url"`
	Method          string `json:"method,omitempty"`
	ServiceKey      string `json:"serviceKey,omitempty"`
	TimeoutMs       int    `json:"timeoutMs,omitempty"`
	CacheTTLSeconds int    `json:"cacheTtlSeconds,omitempty"`
	Required        bool   `json:"required,omitempty"`
}
