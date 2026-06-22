package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerExtensionURL(reg *rpc.Registry) {
	reg.Register("findCollectionAcrossExtensions", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		requestJSON := rpc.Sp(params, "request")
		if requestJSON == "" {
			b, _ := json.Marshal(params)
			requestJSON = string(b)
		}
		return extShare.FindCollectionAcrossExtensions(requestJSON)
	})

	reg.Register("handleURLWithExtension", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		url := rpc.Sp(params, "url")
		if url == "" {
			return "{}", nil
		}
		for _, ext := range extManager.ListExtensions() {
			if ext == nil || !ext.Enabled || ext.Error != "" {
				continue
			}
			if !extRuntime.IsLoaded(ext.ID) {
				continue
			}
			if !extRuntime.HasMethod(ext.ID, "handleUrl") {
				continue
			}
			result, err := extClient.HandleURL(ext.ID, url)
			if err == nil && result != nil && result.Type != "" {
				b, _ := json.Marshal(result)
				return string(b), nil
			}
		}
		return "{}", nil
	})

	reg.Register("findURLHandler", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		url := rpc.Sp(params, "url")
		if url == "" {
			return "", nil
		}
		for _, ext := range extManager.ListExtensions() {
			if ext == nil || !ext.Enabled || ext.Error != "" {
				continue
			}
			if !extRuntime.IsLoaded(ext.ID) {
				continue
			}
			if extRuntime.HasMethod(ext.ID, "handleUrl") {
				return ext.ID, nil
			}
		}
		return "", nil
	})

	reg.Register("getURLHandlers", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		var hh []map[string]interface{}
		for _, ext := range extManager.ListExtensions() {
			if ext == nil || !ext.Enabled || ext.Error != "" {
				continue
			}
			if !extRuntime.IsLoaded(ext.ID) {
				continue
			}
			if !extRuntime.HasMethod(ext.ID, "handleUrl") {
				continue
			}
			hh = append(hh, map[string]interface{}{
				"id":       ext.ID,
				"name":     ext.Name,
				"patterns": []string{"*"},
			})
		}
		b, _ := json.Marshal(hh)
		return string(b), nil
	})
}
