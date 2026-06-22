package handlers

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerExtensionSettings(reg *rpc.Registry) {
	reg.Register("getExtensionSettings", func(params map[string]interface{}) (interface{}, error) {
		extID := rpc.Sp(params, "extension_id")
		if extID == "" {
			return "{}", nil
		}
		extSettingsMu.RLock()
		s, ok := extSettings[extID]
		extSettingsMu.RUnlock()
		if !ok {
			return "{}", nil
		}
		b, _ := json.Marshal(s)
		return string(b), nil
	})

	reg.Register("setExtensionSettings", func(params map[string]interface{}) (interface{}, error) {
		extID := rpc.Sp(params, "extension_id")
		settingsRaw := rpc.Sp(params, "settings")
		if extID == "" {
			return "ok", nil
		}
		var settings map[string]interface{}
		if settingsRaw != "" {
			json.Unmarshal([]byte(settingsRaw), &settings)
		}
		if settings == nil {
			delete(params, "extension_id")
			settings = params
		}
		extSettingsMu.Lock()
		if existing, ok := extSettings[extID]; ok && existing != nil && settings != nil {
			for k, v := range settings {
				existing[k] = v
			}
		} else {
			extSettings[extID] = settings
		}
		extSettingsMu.Unlock()
		return "ok", nil
	})

	// JSON aliases for compatibility with old backend dispatch
	reg.Register("getExtensionSettingsJSON", func(params map[string]interface{}) (interface{}, error) {
		extID := rpc.Sp(params, "extension_id")
		if extID == "" {
			return "{}", nil
		}
		extSettingsMu.RLock()
		s, ok := extSettings[extID]
		extSettingsMu.RUnlock()
		if !ok {
			return "{}", nil
		}
		b, _ := json.Marshal(s)
		return string(b), nil
	})

	reg.Register("setExtensionSettingsJSON", func(params map[string]interface{}) (interface{}, error) {
		extID := rpc.Sp(params, "extension_id")
		settingsRaw := rpc.Sp(params, "settings")
		if extID == "" {
			return "ok", nil
		}
		var settings map[string]interface{}
		if settingsRaw != "" {
			json.Unmarshal([]byte(settingsRaw), &settings)
		}
		if settings == nil {
			delete(params, "extension_id")
			settings = params
		}
		extSettingsMu.Lock()
		if existing, ok := extSettings[extID]; ok && existing != nil && settings != nil {
			for k, v := range settings {
				existing[k] = v
			}
		} else {
			extSettings[extID] = settings
		}
		extSettingsMu.Unlock()
		return "ok", nil
	})

	reg.Register("checkExtensionHealth", func(params map[string]interface{}) (interface{}, error) {
		extID := rpc.Sp(params, "extension_id")
		if extID == "" {
			return `{"healthy":false,"error":"no extension ID"}`, nil
		}
		if extRuntime == nil {
			return `{"healthy":false,"error":"extension runtime not initialized"}`, nil
		}
		if !extRuntime.IsLoaded(extID) {
			return `{"healthy":false,"error":"not loaded"}`, nil
		}
		result, err := extRuntime.CallMethod(extID, "checkHealth")
		if err != nil {
			return fmt.Sprintf(`{"healthy":false,"error":"%s"}`, err.Error()), nil
		}
		if result != nil && result.Value != nil {
			return result.RawJSON, nil
		}
		return `{"healthy":true}`, nil
	})
}
