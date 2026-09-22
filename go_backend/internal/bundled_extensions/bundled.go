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

// ManifestDataDe devuelve SOLO el manifest.json empaquetado de [extID].
//
// Existe porque Load() lee además el index.js completo, y hay un camino que
// solo necesita la versión del manifest: SincronizarConDisco compara versiones
// al arrancar. Con Load() eso leía TODOS los index.js (≈1 MB entre las 9
// extensiones) para tirarlos enseguida, y después LoadAllToRegistry los volvía
// a leer para compilarlos — doble lectura y doble pico de memoria transitoria
// en el arranque, que es justo cuando el teléfono tiene menos margen.
func ManifestDataDe(extID string) ([]byte, error) {
	manifestPath := filepath.ToSlash(extID) + "/manifest.json"
	data, err := fs.ReadFile(FS, manifestPath)
	if err != nil {
		return nil, fmt.Errorf("read embedded %s manifest: %w", extID, err)
	}
	return data, nil
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
