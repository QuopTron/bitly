package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/store"
)

func registerExtensionStore(reg *rpc.Registry) {
	reg.Register("initExtensionStore", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		cacheDir := rpc.Sp(params, "cache_dir")
		if cacheDir != "" && extStore != nil {
			extStore = store.New(extManager, cacheDir)
		}
		return "ok", nil
	})

	reg.Register("setStoreRegistryUrl", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		url := rpc.Sp(params, "url")
		if url == "" {
			url = rpc.Sp(params, "registry_url")
		}
		if url != "" && extStore != nil {
			extStore.SetRegistryURL(url)
		}
		return "ok", nil
	})

	reg.Register("setStoreRegistryURLJSON", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore == nil {
			return "ok", nil
		}
		requestJSON := rpc.Sp(params, "request")
		if requestJSON == "" {
			b, _ := json.Marshal(params)
			requestJSON = string(b)
		}
		var req struct {
			URL string `json:"url"`
		}
		if err := json.Unmarshal([]byte(requestJSON), &req); err == nil && req.URL != "" {
			extStore.SetRegistryURL(req.URL)
		}
		return "ok", nil
	})

	reg.Register("getStoreRegistryUrl", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore == nil {
			return "", nil
		}
		return extStore.GetRegistryURL(), nil
	})

	reg.Register("getStoreRegistryURLJSON", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore == nil {
			return "{}", nil
		}
		b, _ := json.Marshal(map[string]interface{}{"url": extStore.GetRegistryURL()})
		return string(b), nil
	})

	reg.Register("clearStoreRegistryUrl", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore != nil {
			extStore.SetRegistryURL(store.DefaultRegistryURL)
		}
		return "ok", nil
	})

	reg.Register("clearStoreRegistryURLJSON", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore != nil {
			extStore.SetRegistryURL(store.DefaultRegistryURL)
		}
		return "ok", nil
	})

	reg.Register("getStoreCategories", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore == nil {
			return "[]", nil
		}
		cats := extStore.GetCategories()
		b, _ := json.Marshal(cats)
		return string(b), nil
	})

	reg.Register("getStoreCategoriesJSON", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore == nil {
			return "[]", nil
		}
		cats := extStore.GetCategories()
		b, _ := json.Marshal(cats)
		return string(b), nil
	})
}
