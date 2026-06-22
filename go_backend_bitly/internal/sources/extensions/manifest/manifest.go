package manifest

import (
	"encoding/json"
	"fmt"
)

type ExtensionManifest struct {
	Name                   string                 `json:"name"`
	DisplayName            string                 `json:"displayName"`
	Version                string                 `json:"version"`
	Description            string                 `json:"description"`
	Homepage               string                 `json:"homepage,omitempty"`
	Icon                   string                 `json:"icon,omitempty"`
	Types                  []ExtensionType        `json:"type"`
	Permissions            ExtensionPermissions   `json:"permissions"`
	Settings               []ExtensionSetting     `json:"settings,omitempty"`
	QualityOptions         []QualityOption        `json:"qualityOptions,omitempty"`
	MinAppVersion          string                 `json:"minAppVersion,omitempty"`
	SkipMetadataEnrichment bool                   `json:"skipMetadataEnrichment,omitempty"`
	SkipLyrics             bool                   `json:"skipLyrics,omitempty"`
	StopProviderFallback   bool                   `json:"stopProviderFallback,omitempty"`
	SkipBuiltInFallback    bool                   `json:"skipBuiltInFallback,omitempty"`
	SearchBehavior         *SearchBehaviorConfig  `json:"searchBehavior,omitempty"`
	URLHandler             *URLHandlerConfig      `json:"urlHandler,omitempty"`
	TrackMatching          *TrackMatchingConfig   `json:"trackMatching,omitempty"`
	PostProcessing         *PostProcessingConfig  `json:"postProcessing,omitempty"`
	ServiceHealth          []ExtensionHealthCheck `json:"serviceHealth,omitempty"`
	Capabilities           map[string]interface{} `json:"capabilities,omitempty"`
}

type ManifestValidationError struct {
	Field   string
	Message string
}

func (e *ManifestValidationError) Error() string {
	return "manifest validation error: " + e.Field + " - " + e.Message
}

func ParseManifest(data []byte) (*ExtensionManifest, error) {
	var manifest ExtensionManifest
	if err := json.Unmarshal(data, &manifest); err != nil {
		return nil, fmt.Errorf("failed to parse manifest JSON: %w", err)
	}
	if err := manifest.Validate(); err != nil {
		return nil, err
	}
	return &manifest, nil
}
