package handlers

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerExtensionStoreExtDownload(reg *rpc.Registry) {
	reg.Register("downloadStoreExtension", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore == nil {
			return `{"success":false,"error":"store not initialized"}`, nil
		}
		extensionID := rpc.Sp(params, "extension_id")
		if extensionID == "" {
			extensionID = rpc.Sp(params, "id")
		}
		destPath := rpc.Sp(params, "dest_path")
		if destPath == "" {
			destPath = rpc.Sp(params, "destPath")
		}
		if extensionID == "" || destPath == "" {
			return `{"success":false,"error":"extension_id and dest_path required"}`, nil
		}
		if err := extStore.DownloadExtension(extensionID, destPath); err != nil {
			return fmt.Sprintf(`{"success":false,"error":"%s"}`, err.Error()), nil
		}
		return `{"success":true}`, nil
	})

	reg.Register("downloadStoreExtensionJSON", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore == nil {
			return `{"success":false,"error":"store not initialized"}`, nil
		}
		requestJSON := rpc.Sp(params, "request")
		if requestJSON == "" {
			extensionID := rpc.Sp(params, "extension_id")
			if extensionID == "" {
				extensionID = rpc.Sp(params, "id")
			}
			destPath := rpc.Sp(params, "dest_path")
			if destPath == "" {
				destPath = rpc.Sp(params, "destPath")
			}
			if extensionID != "" && destPath != "" {
				if err := extStore.DownloadExtension(extensionID, destPath); err != nil {
					return fmt.Sprintf(`{"success":false,"error":"%s"}`, err.Error()), nil
				}
				return `{"success":true}`, nil
			}
			return `{"success":false,"error":"extension_id and dest_path required"}`, nil
		}
		var req struct {
			ExtensionID string `json:"extension_id"`
			ID          string `json:"id"`
			DestPath    string `json:"dest_path"`
			DestPathAlt string `json:"destPath"`
		}
		if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
			return fmt.Sprintf(`{"success":false,"error":"invalid request: %s"}`, err.Error()), nil
		}
		extensionID := req.ExtensionID
		if extensionID == "" {
			extensionID = req.ID
		}
		destPath := req.DestPath
		if destPath == "" {
			destPath = req.DestPathAlt
		}
		if extensionID == "" || destPath == "" {
			return `{"success":false,"error":"extension_id and dest_path required"}`, nil
		}
		if err := extStore.DownloadExtension(extensionID, destPath); err != nil {
			return fmt.Sprintf(`{"success":false,"error":"%s"}`, err.Error()), nil
		}
		return `{"success":true}`, nil
	})

	reg.Register("clearStoreCache", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore != nil {
			extStore.ClearCache()
		}
		return "ok", nil
	})

	reg.Register("clearStoreCacheJSON", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		if extStore != nil {
			extStore.ClearCache()
		}
		return "ok", nil
	})
}
