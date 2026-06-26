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
		extDir := rpc.Sp(params, "extensions_dir")
		if extDir == "" {
			extDir = rpc.Sp(params, "cache_dir")
		}
		dataDir := rpc.Sp(params, "data_dir")
		if dataDir == "" && extDir != "" {
			dataDir = filepath.Join(extDir, "..", "ext_data")
		}
		if extDir != "" {
			extManager.SetDirectories(extDir, dataDir)
		}
		// Load bundled extensions from the Go binary as a fallback.
		// This ensures extensions are always available even when the
		// Android filesystem copies haven't completed yet.
		loadEmbeddedExtensions()
		return "ok", nil
	})

	reg.Register("loadExtensionsFromDir", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		dirPath := rpc.Sp(params, "dir_path")
		fmt.Printf("[extensions] loadExtensionsFromDir: dir=%q\n", dirPath)
		if dirPath == "" {
			fmt.Println("[extensions] loadExtensionsFromDir: empty dir path")
			return "[]", nil
		}
		entries, err := os.ReadDir(dirPath)
		if err != nil {
			fmt.Printf("[extensions] loadExtensionsFromDir: cannot read dir %q: %v\n", dirPath, err)
			return "[]", nil
		}
		fmt.Printf("[extensions] loadExtensionsFromDir: found %d entries\n", len(entries))
		var loaded []*manager.Extension
		for _, entry := range entries {
			if !entry.IsDir() || strings.HasPrefix(entry.Name(), ".") {
				continue
			}
			extDir := filepath.Join(dirPath, entry.Name())
			fmt.Printf("[extensions] loadExtensionsFromDir: trying %q\n", extDir)
			ext, err := extManager.LoadExtensionFromDir(extDir)
			if err != nil {
				fmt.Printf("[extensions] LoadExtensionFromDir failed for %q: %v\n", extDir, err)
				continue
			}
			jsPath := filepath.Join(extDir, "index.js")
			fmt.Printf("[extensions] loading %q (id=%s) into runtime from %s\n", ext.ID, ext.ID, jsPath)
			if err := extRuntime.LoadExtensionWithDirs(ext.ID, jsPath, ext.SourceDir, ext.DataDir, ext.Manifest); err != nil {
				fmt.Printf("[extensions] LoadExtensionWithDirs failed for %q: %v\n", ext.ID, err)
				continue
			}
			fmt.Printf("[extensions] successfully loaded %q\n", ext.ID)
			loaded = append(loaded, ext)
		}
		fmt.Printf("[extensions] loadExtensionsFromDir: loaded %d extensions\n", len(loaded))
		for _, l := range loaded {
			fmt.Printf("[extensions]   - %s (v%s, enabled=%v)\n", l.ID, l.Version, l.Enabled)
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
