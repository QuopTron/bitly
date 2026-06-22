package manager

import (
	"archive/zip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

func (m *Manager) LoadExtension(filePath string) (*Extension, error) {
	if strings.TrimSpace(filePath) == "" {
		return nil, fmt.Errorf("invalid file path")
	}

	isZipSuffix := strings.HasSuffix(strings.ToLower(filePath), ".bitly-ext")
	zipReader, err := zip.OpenReader(filePath)
	if err != nil {
		if !isZipSuffix {
			return nil, fmt.Errorf("invalid file format: please select a .bitly-ext file")
		}
		return nil, fmt.Errorf("cannot open extension file: the file may be corrupted")
	}
	defer zipReader.Close()

	manifestData, hasIndexJS := readManifestFromZip(zipReader)
	if manifestData == nil {
		return nil, fmt.Errorf("invalid extension package: manifest.json not found")
	}
	if !hasIndexJS {
		return nil, fmt.Errorf("invalid extension package: index.js not found")
	}

	pManifest, err := manifest.ParseManifest(manifestData)
	if err != nil {
		return nil, fmt.Errorf("invalid extension manifest: %w", err)
	}

	m.mu.RLock()
	existing, exists := m.extensions[pManifest.Name]
	m.mu.RUnlock()

	if exists {
		cmp := manifest.CompareVersions(pManifest.Version, existing.Version)
		if cmp > 0 {
			return m.upgradeExtension(zipReader, pManifest, existing)
		} else if cmp == 0 {
			return nil, fmt.Errorf("extension '%s' v%s is already installed",
				pManifest.DisplayName, existing.Version)
		} else {
			return nil, fmt.Errorf("cannot downgrade '%s' from v%s to v%s",
				pManifest.DisplayName, existing.Version, pManifest.Version)
		}
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.extensions[pManifest.Name]; exists {
		return nil, fmt.Errorf("extension '%s' was installed by another process",
			pManifest.DisplayName)
	}

	return m.extractFromZipAndRegister(zipReader, pManifest)
}

func readManifestFromZip(zipReader *zip.ReadCloser) ([]byte, bool) {
	var manifestData []byte
	hasIndexJS := false
	for _, f := range zipReader.File {
		name := filepath.Base(f.Name)
		if name == "manifest.json" {
			rc, err := f.Open()
			if err != nil {
				continue
			}
			manifestData, err = io.ReadAll(rc)
			rc.Close()
			if err != nil {
				manifestData = nil
			}
		}
		if name == "index.js" {
			hasIndexJS = true
		}
	}
	return manifestData, hasIndexJS
}

func (m *Manager) extractFromZipAndRegister(zipReader *zip.ReadCloser, pManifest *manifest.ExtensionManifest) (*Extension, error) {
	extDir := filepath.Join(m.extensionsDir, pManifest.Name)
	if err := os.MkdirAll(extDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create extension directory: %w", err)
	}

	if err := extractZipFiles(zipReader, extDir); err != nil {
		return nil, err
	}

	extDataDir := filepath.Join(m.dataDir, pManifest.Name)
	if err := os.MkdirAll(extDataDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create extension data directory: %w", err)
	}

	return m.registerExtension(pManifest, extDir, extDataDir, false), nil
}
