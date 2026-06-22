package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerExtensionStoreExt(reg *rpc.Registry) {
	reg.Register("getStoreExtensions", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore == nil {
			return "[]", nil
		}
		forceRefresh := rpc.Sp(params, "force_refresh") == "true" || rpc.Sb(params, "force_refresh")
		result, err := extStore.GetExtensionsWithStatus(forceRefresh)
		if err != nil || result == nil {
			return "[]", nil
		}
		b, _ := json.Marshal(result)
		return string(b), nil
	})

	reg.Register("getStoreExtensionsJSON", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore == nil {
			return "[]", nil
		}
		forceRefresh := rpc.Sp(params, "force_refresh") == "true" || rpc.Sb(params, "force_refresh")
		result, err := extStore.GetExtensionsWithStatus(forceRefresh)
		if err != nil || result == nil {
			return "[]", nil
		}
		b, _ := json.Marshal(result)
		return string(b), nil
	})

	reg.Register("searchStoreExtensions", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore == nil {
			return "[]", nil
		}
		query := rpc.Sp(params, "query")
		category := rpc.Sp(params, "category")
		result, err := extStore.SearchExtensions(query, category)
		if err != nil || result == nil {
			return "[]", nil
		}
		b, _ := json.Marshal(result)
		return string(b), nil
	})

	reg.Register("searchStoreExtensionsJSON", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore == nil {
			return "[]", nil
		}
		requestJSON := rpc.Sp(params, "request")
		query := rpc.Sp(params, "query")
		category := rpc.Sp(params, "category")
		if requestJSON != "" {
			var req struct {
				Query    string `json:"query"`
				Category string `json:"category"`
			}
			if err := json.Unmarshal([]byte(requestJSON), &req); err == nil {
				if query == "" {
					query = req.Query
				}
				if category == "" {
					category = req.Category
				}
			}
		}
		result, err := extStore.SearchExtensions(query, category)
		if err != nil || result == nil {
			return "[]", nil
		}
		b, _ := json.Marshal(result)
		return string(b), nil
	})

	registerExtensionStoreExtDownload(reg)
}
