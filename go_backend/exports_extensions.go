package gobackend

import (
	"encoding/json"
	"time"

	"github.com/zarz/bitly/go_backend/internal/extensions"
	"github.com/zarz/bitly/go_backend/internal/provider"
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
	// Re-apply stored settings (OAuth tokens, credentials) to extensions whose
	// sandbox just finished loading — a startup push may have raced it.
	replayStoredExtensionSettings()
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
	// Primary mirrors the manifest's searchBehavior.primary — the default
	// search source (SpotiFLAC's defaultSearchExtension). The UI preselects
	// it and the backend tries it first on a "Todas" search.
	Primary        bool                `json:"primary"`
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
			Primary:        e.Search.Primary,
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
		}
		// The extension sandbox may not exist yet (startup race: the push can
		// land while extensions are still loading). Settings are stored above;
		// retry initialize for a short window so credentials are not lost — a
		// subsequent replay at load time covers the case where even this retry
		// window closes before the sandbox appears.
		go retryInitializeAfterLoad(params.ExtensionID, settings)
	}
	return `{"ok":true}`
}

// retryInitializeAfterLoad repeatedly calls initialize() on an extension once
// its sandbox becomes available. Bounded (~6s) and best-effort: if the window
// passes the settings stay stored and replayStoredExtensionSettings() applies
// them when the sandbox finally loads.
func retryInitializeAfterLoad(extID string, settings map[string]string) {
	for i := 0; i < 20; i++ {
		time.Sleep(300 * time.Millisecond)
		if extRegistry == nil {
			return
		}
		sb := extRegistry.Runtime().Sandbox(extID)
		if sb == nil || sb.VM == nil {
			continue
		}
		_, err := extRegistry.Runtime().CallMethod(extID, "initialize", settings)
		if err == nil {
			return
		}
	}
}

// replayStoredExtensionSettings re-applies every stored setting set to an
// extension whose sandbox is now present. Call it after any extension-loading
// step (InitGlobalState, initExtensionSystem, loadExtensionsFromDir) so a
// credential push that raced a slow sandbox load is not lost.
func replayStoredExtensionSettings() int {
	if extRegistry == nil || extSettings == nil {
		return 0
	}
	applied := 0
	for extID, settings := range extSettings {
		sb := extRegistry.Runtime().Sandbox(extID)
		if sb == nil || sb.VM == nil {
			continue
		}
		if _, err := extRegistry.Runtime().CallMethod(extID, "initialize", settings); err == nil {
			applied++
		}
	}
	return applied
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

// InvokeExtensionAction runs a side-effect action exported by an extension
// (SpotiFLAC button-setting contract). The provider extension must export a
// JS method with the action's name; the result is passed back verbatim so the
// UI can surface status/errors from the action itself.
// Flutter contract: {provider, action, args?: [...]}.
func InvokeExtensionAction(payload string) string {
	var params struct {
		Provider string        `json:"provider"`
		Action   string        `json:"action"`
		Args     []interface{} `json:"args"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonErrorStr("payload inválido")
	}
	if params.Provider == "" || params.Action == "" {
		return jsonErrorStr("faltan provider/action")
	}
	if reg == nil {
		return jsonErrorStr("no inicializado")
	}
	p := reg.Get(params.Provider)
	ep, ok := p.(*provider.ExtensionProvider)
	if !ok || !ep.HasAction(params.Action) {
		return jsonErrorStr("extensión " + params.Provider + " no exporta la acción " + params.Action)
	}
	res, err := ep.InvokeAction(params.Action, params.Args...)
	if err != nil {
		return jsonError(err)
	}
	out, _ := json.Marshal(map[string]interface{}{"ok": true, "result": res})
	return string(out)
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
	// Re-apply stored settings now that freshly loaded sandboxes exist.
	replayStoredExtensionSettings()
	out, _ := json.Marshal(map[string]interface{}{"ok": true, "loaded": loaded})
	return string(out)
}
