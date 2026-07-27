// Package bundled_extensions embeds all extension JS source and manifests
// directly into the Go binary so they are always available.
package bundled_extensions

import (
	"embed"
	"fmt"
	"io/fs"
	"path/filepath"
	"strings"
)

//go:embed amazon apple-music deezer pandora qobuz-web soundcloud spotify-web tidal-web ytmusic-spotiflac
var FS embed.FS

// ExtensionFiles holds the paths to an extension's core files.
type ExtensionFiles struct {
	ID           string
	SourceDir    string
	IndexJSPath  string
	ManifestPath string
	ManifestData []byte
	IndexJSData  []byte
}

// List returns the names of all extension directories found in the embedded FS.
func List() ([]string, error) {
	entries, err := fs.ReadDir(FS, ".")
	if err != nil {
		return nil, fmt.Errorf("read embedded extensions root: %w", err)
	}
	var dirs []string
	for _, e := range entries {
		if e.IsDir() && !strings.HasPrefix(e.Name(), ".") {
			dirs = append(dirs, e.Name())
		}
	}
	return dirs, nil
}

// Load reads an extension's index.js and manifest.json from the embedded filesystem.
func Load(extID string) (*ExtensionFiles, error) {
	base := filepath.ToSlash(extID)

	manifestPath := base + "/manifest.json"
	manifestData, err := fs.ReadFile(FS, manifestPath)
	if err != nil {
		return nil, fmt.Errorf("read embedded %s manifest: %w", extID, err)
	}

	jsPath := base + "/index.js"
	jsData, err := fs.ReadFile(FS, jsPath)
	if err != nil {
		return nil, fmt.Errorf("read embedded %s index.js: %w", extID, err)
	}

	return &ExtensionFiles{
		ID:           extID,
		SourceDir:    base,
		IndexJSPath:  jsPath,
		ManifestPath: manifestPath,
		ManifestData: manifestData,
		IndexJSData:  jsData,
	}, nil
}
