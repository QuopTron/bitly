package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// =========================================================================
// EXTENSIONS — System management
// =========================================================================

func InitExtensionSystem(payload string) string {
	var params struct {
		ExtensionsDir string `json:"extensions_dir"`
		DataDir       string `json:"data_dir"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}

	// Don't clobber an already-populated extRegistry: InitGlobalState loads
	// the embedded extensions WITH signed-session config attached. If we
	// replaced it here, the Cloudflare verification flow would find no
	// sandbox/session and no auth URL would ever be returned.
	if extRegistry == nil || extRegistry.Runtime().Count() == 0 {
		extRegistry = extensions.NewRegistryBestEffort(params.ExtensionsDir)
	}
	// Load any on-disk extensions (subdir layout) into the existing registry.
	_ = extensions.LoadDirExtensionsInto(extRegistry, params.ExtensionsDir, params.DataDir)
	data, _ := json.Marshal(extRegistry.List())
	return string(data)
}

func GetInstalledExtensions() string {
	if extRegistry == nil {
		return `[]`
	}
	data, _ := json.Marshal(extRegistry.List())
	return string(data)
}

// GetBundledExtensions returns the list of bundled (embedded) extensions.
func GetBundledExtensions() string {
	if len(bundledExts) == 0 {
		return `[]`
	}
	data, _ := json.Marshal(bundledExts)
	return string(data)
}

// SearchFilterConfig is the Flutter-facing shape of one search category bubble.
type SearchFilterConfig struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Icon  string `json:"icon"`
}

// SourceSearchConfig maps a source id to the search qualifiers declared in its
// manifest (searchBehavior), so Flutter can build the category bubbles per
// source exactly as the extension intends — the Bitly flow equivalent of
// SpotiFLAC reading the manifest.
type SourceSearchConfig struct {
	Source         string              `json:"source"`
	ThumbnailRatio string              `json:"thumbnailRatio,omitempty"`
	Placeholder    string              `json:"placeholder,omitempty"`
	Filters        []SearchFilterConfig `json:"filters"`
}

// GetSearchConfig returns the search category bubbles for every bundled source
// that declares a searchBehavior. Sources without one (e.g. pandora) are
// omitted so the UI offers no bogus category chips for them.
func GetSearchConfig() string {
	out := make([]SourceSearchConfig, 0, len(bundledExts))
	for _, e := range bundledExts {
		if len(e.Search.Filters) == 0 {
			continue
		}
		cfg := SourceSearchConfig{
			Source:         e.ID,
			ThumbnailRatio: e.Search.ThumbnailRatio,
			Placeholder:    e.Search.Placeholder,
			Filters:        make([]SearchFilterConfig, 0, len(e.Search.Filters)),
		}
		for _, f := range e.Search.Filters {
			cfg.Filters = append(cfg.Filters, SearchFilterConfig{
				ID:    f.ID,
				Label: f.Label,
				Icon:  f.Icon,
			})
		}
		out = append(out, cfg)
	}
	data, err := json.Marshal(out)
	if err != nil {
		return `[]`
	}
	return string(data)
}

// SetExtensionSettings stores settings for an extension in memory and pushes them
// to the JS initialize() function so credentials take effect.
// Flutter contract: {extension_id, settings} where settings is a JSON string.
func SetExtensionSettings(payload string) string {
	var params struct {
		ExtensionID string `json:"extension_id"`
		Settings    string `json:"settings"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonErrorStr("payload inválido")
	}
	if params.ExtensionID == "" {
		return jsonErrorStr("falta extension_id")
	}
	settings := map[string]string{}
	if params.Settings != "" {
		if err := json.Unmarshal([]byte(params.Settings), &settings); err != nil {
			return jsonError(err)
		}
	}
	if extSettings == nil {
		extSettings = make(map[string]map[string]string)
	}
	extSettings[params.ExtensionID] = settings

	// Push settings to the JS initialize() function if the extension is loaded.
	if extRegistry != nil {
		if sb := extRegistry.Runtime().Sandbox(params.ExtensionID); sb != nil && sb.VM != nil {
			if _, err := extRegistry.Runtime().CallMethod(params.ExtensionID, "initialize", settings); err == nil {
				return `{"ok":true}`
			}
			// If initialize failed, settings are still stored for the next
			// ReinitializeExtension call.
		}
	}
	return `{"ok":true}`
}

// ReinitializeExtension re-runs the JS initialize() with the stored settings.
// Flutter contract: {extension_id}.
func ReinitializeExtension(payload string) string {
	var params struct {
		ExtensionID string `json:"extension_id"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil || params.ExtensionID == "" {
		return jsonErrorStr("payload inválido")
	}
	if extRegistry == nil {
		return jsonErrorStr("no inicializado")
	}
	settings := extSettings[params.ExtensionID]
	if settings == nil {
		settings = map[string]string{}
	}
	sb := extRegistry.Runtime().Sandbox(params.ExtensionID)
	if sb == nil {
		return jsonErrorStr("extensión no cargada: " + params.ExtensionID)
	}
	if _, err := extRegistry.Runtime().CallMethod(params.ExtensionID, "initialize", settings); err != nil {
		return jsonError(err)
	}
	return `{"ok":true}`
}

// LoadExtensionsFromDir loads all .js extensions from a directory into the runtime
// and registers their providers. Used by the desktop backend.
// Flutter contract: {dir_path}.
func LoadExtensionsFromDir(payload string) string {
	var params struct {
		DirPath string `json:"dir_path"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil || params.DirPath == "" {
		return jsonErrorStr("falta dir_path")
	}

	// Reuse the existing registry (embedded extensions already loaded by
	// InitGlobalState with signed-session config attached). Only create one
	// if nothing is loaded yet (e.g. desktop without embedded fallback).
	if extRegistry == nil || extRegistry.Runtime().Count() == 0 {
		reg, err := extensions.NewRegistry(params.DirPath)
		if err != nil {
			return jsonError(err)
		}
		extRegistry = reg
	}
	loaded := extensions.LoadDirExtensionsInto(extRegistry, params.DirPath, params.DirPath)
	out, _ := json.Marshal(map[string]interface{}{"ok": true, "loaded": loaded})
	return string(out)
}
