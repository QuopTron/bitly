package handlers

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manager"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

func registerExtensionLifecycle(reg *rpc.Registry) {
	reg.Register("initExtensionSystem", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		cacheDir := rpc.Sp(params, "cache_dir")
		if cacheDir != "" {
			extManager.SetDirectories(filepath.Join(cacheDir, "extensions"), filepath.Join(cacheDir, "ext_data"))
		}
		return "ok", nil
	})

	reg.Register("loadExtensionsFromDir", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		dirPath := rpc.Sp(params, "dir_path")
		if dirPath == "" {
			return "[]", nil
		}
		entries, err := os.ReadDir(dirPath)
		if err != nil {
			return "[]", nil
		}
		var loaded []*manager.Extension
		for _, entry := range entries {
			if !entry.IsDir() || strings.HasPrefix(entry.Name(), ".") {
				continue
			}
			extDir := filepath.Join(dirPath, entry.Name())
			ext, err := extManager.LoadExtensionFromDir(extDir)
			if err != nil {
				continue
			}
			jsPath := filepath.Join(extDir, "index.js")
			if err := extRuntime.LoadExtensionWithDirs(ext.ID, jsPath, ext.SourceDir, ext.DataDir, ext.Manifest); err != nil {
				continue
			}
			loaded = append(loaded, ext)
		}
		b, _ := json.Marshal(loaded)
		return string(b), nil
	})

	reg.Register("loadExtensionFromPath", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		filePath := rpc.Sp(params, "file_path")
		if filePath == "" {
			return "{}", nil
		}
		ext, err := extManager.LoadExtension(filePath)
		if err != nil {
			return "{}", nil
		}
		jsPath := filepath.Join(ext.SourceDir, "index.js")
		extRuntime.LoadExtension(ext.ID, jsPath)
		b, _ := json.Marshal(ext)
		return string(b), nil
	})

	reg.Register("unloadExtension", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		id := rpc.Sp(params, "extension_id")
		extRuntime.UnloadExtension(id)
		return "ok", extManager.UnloadExtension(id)
	})

	reg.Register("removeExtension", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		id := rpc.Sp(params, "extension_id")
		extRuntime.UnloadExtension(id)
		return "ok", extManager.UnloadExtension(id)
	})

	reg.Register("upgradeExtension", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		filePath := rpc.Sp(params, "file_path")
		if filePath == "" {
			return `{"upgraded":false,"error":"no file path"}`, nil
		}
		ext, err := extManager.LoadExtension(filePath)
		if err != nil {
			return fmt.Sprintf(`{"upgraded":false,"error":"%s"}`, err.Error()), nil
		}
		if extRuntime.IsLoaded(ext.ID) {
			extRuntime.UnloadExtension(ext.ID)
		}
		jsPath := filepath.Join(ext.SourceDir, "index.js")
		extRuntime.LoadExtension(ext.ID, jsPath)
		return `{"upgraded":true}`, nil
	})

	reg.Register("checkExtensionUpgrade", func(params map[string]interface{}) (interface{}, error) {
		filePath := rpc.Sp(params, "file_path")
		if filePath == "" {
			return `{"has_upgrade":false}`, nil
		}
		newVersion, newName, err := readManifestVersionFromZip(filePath)
		if err != nil {
			return fmt.Sprintf(`{"has_upgrade":false,"error":"%s"}`, err.Error()), nil
		}
		if existing, err := extManager.GetExtension(newName); err == nil && existing != nil {
			cmp := manifest.CompareVersions(newVersion, existing.Version)
			if cmp > 0 {
				return `{"has_upgrade":true}`, nil
			}
			if cmp == 0 {
				return `{"has_upgrade":false,"reason":"already installed"}`, nil
			}
			return `{"has_upgrade":false,"reason":"downgrade would be required"}`, nil
		}
		return `{"has_upgrade":true,"is_new":true}`, nil
	})

	reg.Register("cleanupExtensions", func(params map[string]interface{}) (interface{}, error) {
		return "ok", nil
	})
}
