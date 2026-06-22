package handlers

import (
	"encoding/json"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerExtensionInvokeExtra(reg *rpc.Registry) {
	reg.Register("customSearchWithExtension", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		extID := rpc.Sp(params, "extension_id")
		query := rpc.Sp(params, "query")
		optionsStr := rpc.Sp(params, "options")
		if extID == "" || query == "" {
			return "[]", nil
		}
		if !extRuntime.IsLoaded(extID) {
			return "[]", nil
		}
		var options map[string]interface{}
		if optionsStr != "" {
			json.Unmarshal([]byte(optionsStr), &options)
		}
		if options == nil {
			options = map[string]interface{}{"limit": 20}
		}
		result, err := extRuntime.CallMethod(extID, "customSearch", query, options)
		if err != nil || result == nil || result.Value == nil {
			return "[]", nil
		}
		var tracks []interface{}
		if err := json.Unmarshal([]byte(result.RawJSON), &tracks); err == nil {
			return result.RawJSON, nil
		}
		var wrapper struct {
			Tracks []interface{} `json:"tracks"`
			Total  int           `json:"total"`
		}
		if err := json.Unmarshal([]byte(result.RawJSON), &wrapper); err == nil {
			b, _ := json.Marshal(wrapper.Tracks)
			return string(b), nil
		}
		return result.RawJSON, nil
	})

	reg.Register("getSearchProviders", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		var providers []map[string]interface{}
		providers = append(providers, map[string]interface{}{
			"id":                "__deezer",
			"name":              "Deezer",
			"type":              "music",
			"has_custom_search": true,
			"search_behavior": map[string]interface{}{
				"primary": true,
				"filters": []string{"track", "artist", "album", "playlist"},
			},
		})
		for _, ext := range extManager.ListExtensions() {
			if ext == nil || !ext.Enabled || ext.Error != "" {
				continue
			}
			extType := ext.Type
			if !strings.Contains(extType, "metadata_provider") && !strings.Contains(extType, "lyrics_provider") {
				continue
			}
			provider := map[string]interface{}{
				"id":                ext.ID,
				"name":              ext.Name,
				"type":              ext.Type,
				"has_custom_search": extRuntime.HasMethod(ext.ID, "customSearch"),
			}
			providers = append(providers, provider)
		}
		b, _ := json.Marshal(providers)
		return string(b), nil
	})
}
