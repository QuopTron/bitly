package manager

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

func (m *Manager) LoadExtensionFromDir(dirPath string) (*Extension, error) {
	manifestPath := filepath.Join(dirPath, "manifest.json")
	manifestData, err := os.ReadFile(manifestPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read manifest.json: %w", err)
	}
	pManifest, err := manifest.ParseManifest(manifestData)
	if err != nil {
		return nil, fmt.Errorf("invalid extension manifest: %w", err)
	}

	indexPath := filepath.Join(dirPath, "index.js")
	if _, err := os.Stat(indexPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("extension is missing index.js file")
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	if existing, exists := m.extensions[pManifest.Name]; exists {
		return existing, nil
	}

	extDataDir := filepath.Join(m.dataDir, pManifest.Name)
	if err := os.MkdirAll(extDataDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create extension data directory: %w", err)
	}

	return m.registerExtension(pManifest, dirPath, extDataDir, false), nil
}
