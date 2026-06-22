package manifest

import (
	"fmt"
	"strings"
)

func (m *ExtensionManifest) Validate() error {
	if strings.TrimSpace(m.Name) == "" {
		return &ManifestValidationError{Field: "name", Message: "name is required"}
	}

	if strings.TrimSpace(m.Version) == "" {
		return &ManifestValidationError{Field: "version", Message: "version is required"}
	}

	if strings.TrimSpace(m.Description) == "" {
		return &ManifestValidationError{Field: "description", Message: "description is required"}
	}

	if len(m.Types) == 0 {
		return &ManifestValidationError{Field: "type", Message: "at least one type is required"}
	}

	for _, t := range m.Types {
		if t != ExtensionTypeMetadataProvider && t != ExtensionTypeDownloadProvider && t != ExtensionTypeLyricsProvider {
			return &ManifestValidationError{
				Field:   "type",
				Message: fmt.Sprintf("invalid extension type: %s", t),
			}
		}
	}

	for i, setting := range m.Settings {
		if strings.TrimSpace(setting.Key) == "" {
			return &ManifestValidationError{
				Field:   fmt.Sprintf("settings[%d].key", i),
				Message: "setting key is required",
			}
		}
		if setting.Type == "" {
			return &ManifestValidationError{
				Field:   fmt.Sprintf("settings[%d].type", i),
				Message: "setting type is required",
			}
		}
		if setting.Type == SettingTypeSelect && len(setting.Options) == 0 {
			return &ManifestValidationError{
				Field:   fmt.Sprintf("settings[%d].options", i),
				Message: "select type requires options",
			}
		}
		if setting.Type == SettingTypeButton && setting.Action == "" {
			return &ManifestValidationError{
				Field:   fmt.Sprintf("settings[%d].action", i),
				Message: "button type requires action (JS function name)",
			}
		}
	}

	for i, check := range m.ServiceHealth {
		if strings.TrimSpace(check.ID) == "" {
			return &ManifestValidationError{
				Field:   fmt.Sprintf("serviceHealth[%d].id", i),
				Message: "health check id is required",
			}
		}
		if strings.TrimSpace(check.URL) == "" {
			return &ManifestValidationError{
				Field:   fmt.Sprintf("serviceHealth[%d].url", i),
				Message: "health check url is required",
			}
		}
		method := strings.ToUpper(strings.TrimSpace(check.Method))
		if method != "" && method != "GET" && method != "HEAD" {
			return &ManifestValidationError{
				Field:   fmt.Sprintf("serviceHealth[%d].method", i),
				Message: "health check method must be GET or HEAD",
			}
		}
	}

	return nil
}
