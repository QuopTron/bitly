package handlers

import (
	"encoding/json"
	"path/filepath"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerExtensionQuery(reg *rpc.Registry) {
	reg.Register("getInstalledExtensions", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		exts := extManager.ListExtensions()
		if exts == nil {
			return "[]", nil
		}
		b, _ := json.Marshal(exts)
		return string(b), nil
	})

	reg.Register("setExtensionEnabled", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		id := rpc.Sp(params, "extension_id")
		enabled := false
		if v, ok := params["enabled"]; ok {
			switch val := v.(type) {
			case bool:
				enabled = val
			case string:
				enabled = val == "true" || val == "1"
			case int64:
				enabled = val == 1
			case float64:
				enabled = val == 1
			}
		}
		if err := extManager.SetExtensionEnabled(id, enabled); err != nil {
			return "ok", nil
		}
		if enabled {
			if !extRuntime.IsLoaded(id) {
				if ext, err := extManager.GetExtension(id); err == nil && ext != nil {
					jsPath := filepath.Join(ext.SourceDir, "index.js")
					extRuntime.LoadExtensionWithDirs(id, jsPath, ext.SourceDir, ext.DataDir, ext.Manifest)
				}
			}
		} else {
			extRuntime.UnloadExtension(id)
		}
		return "ok", nil
	})
}
