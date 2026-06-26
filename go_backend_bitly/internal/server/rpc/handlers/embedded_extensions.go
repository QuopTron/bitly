package handlers

import (
	"fmt"
	"os"

	"github.com/zarz/bitly/go_backend_bitly/internal/bundled_extensions"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

// loadEmbeddedExtensions loads all bundled extensions into the runtime
// that are not already loaded. This provides a robust fallback when the
// Android filesystem copies haven't completed yet.
func loadEmbeddedExtensions() {
	// NOTE: Caller must have called ensureExtensionInit() first.
	// This is now called from within ensureExtensionInit(), so the
	// runtime, manager, and client are guaranteed to be initialized.

	dirs, err := bundled_extensions.ListExtensionDirs()
	if err != nil {
		fmt.Printf("[extensions] embedded list error: %v\n", err)
		return
	}

	var loaded int
	for _, dir := range dirs {
		// Skip if already loaded from filesystem
		if extRuntime.IsLoaded(dir) {
			continue
		}

		extFiles, err := bundled_extensions.LoadExtension(dir)
		if err != nil {
			fmt.Printf("[extensions] embedded load %q error: %v\n", dir, err)
			continue
		}

		// Parse manifest
		mf, err := manifest.ParseManifest(extFiles.ManifestData)
		if err != nil {
			fmt.Printf("[extensions] embedded parse manifest %q error: %v\n", dir, err)
			continue
		}

		// Register in the manager first (so ListExtensions works)
		if _, err := extManager.RegisterExtensionFromData(dir, mf); err != nil {
			fmt.Printf("[extensions] embedded register %q error: %v\n", dir, err)
		}

		// Use extensions dir as data dir, or a temp dir fallback
		dataDir := extManager.ExtensionsDir()
		if dataDir == "" {
			dataDir = fmt.Sprintf("%s/bitly-ext-data/%s", os.TempDir(), dir)
		}

		// Load directly into JS runtime (no filesystem needed)
		err = extRuntime.InlineLoad(dir, extFiles.IndexJSData, extFiles.SourceDir, dataDir, mf)
		if err != nil {
			fmt.Printf("[extensions] embedded runtime load %q error: %v\n", dir, err)
			continue
		}

		fmt.Printf("[extensions] embedded: loaded %q (from binary)\n", dir)
		loaded++
	}

	if loaded > 0 {
		fmt.Printf("[extensions] embedded: loaded %d extensions from binary\n", loaded)
	}
}
