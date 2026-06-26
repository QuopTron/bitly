// Package bundled_extensions embeds all extension JS source and manifests
// directly into the Go binary so they are always available even when the
// Android filesystem copies fail or are not yet in place.
package bundled_extensions

import (
	"embed"
	"fmt"
	"io/fs"
	"path/filepath"
	"strings"
)

// FS provides access to the bundled extension files.
//
//go:embed amazon apple-music deezer pandora qobuz-web soundcloud spotify-web tidal-web ytmusic-spotiflac
var FS embed.FS

// ExtensionFiles holds the paths to an extension's core files.
type ExtensionFiles struct {
	ID             string
	SourceDir      string // directory within the embedded FS
	IndexJSPath    string // path to index.js within the embedded FS
	ManifestPath   string // path to manifest.json within the embedded FS
	ManifestData   []byte
	IndexJSData    []byte
}

// ListExtensionDirs returns the names of all extension directories found
// in the embedded FS.
func ListExtensionDirs() ([]string, error) {
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

// LoadExtension reads an extension's index.js and manifest.json from the
// embedded filesystem.
func LoadExtension(extID string) (*ExtensionFiles, error) {
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
