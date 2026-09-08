package gobackend

import (
	"encoding/json"
	"time"
)

// SetExtensionSettings stores settings for an extension in memory and pushes them
// to the JS initialize() function so credentials take effect.
// Flutter contract: {extension_id, settings} where settings is a JSON string.
func SetExtensionSettings(payload string) string {
	var params struct {
		ExtensionID string `json:"extension_id"`
		Settings    string `json:"settings"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonErrorString("payload inválido")
	}
	if params.ExtensionID == "" {
		return jsonErrorString("falta extension_id")
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
		// The extension sandbox puede sin exist yet (startup race: el push puede
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
// passes the settings stay stored and replicarAjustesExtensiones() applies
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

// replicarAjustesExtensiones vuelve a aplicar cada ajuste guardado a una
// extensión cuyo sandbox ya está presente. Se llama después de cada paso de
// carga de extensiones (InitGlobalState, initExtensionSystem,
// loadExtensionsFromDir) para que un push de credenciales que corrió contra
// una carga lenta de sandbox no se pierda.
func replicarAjustesExtensiones() int {
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
