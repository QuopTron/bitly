package manager

import (
	"fmt"
	"os"
	"sync"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

type Extension struct {
	ID           string                      `json:"id"`
	Name         string                      `json:"name"`
	Version      string                      `json:"version"`
	Enabled      bool                        `json:"enabled"`
	Type         string                      `json:"type"`
	SourceDir    string                      `json:"source_dir"`
	DataDir      string                      `json:"data_dir"`
	Capabilities map[string]interface{}      `json:"capabilities,omitempty"`
	Error        string                      `json:"error,omitempty"`
	Manifest     *manifest.ExtensionManifest `json:"-"`
}

type Manager struct {
	mu            sync.RWMutex
	extensions    map[string]*Extension
	extensionsDir string
	dataDir       string
}

func NewManager() *Manager {
	return &Manager{
		extensions: make(map[string]*Extension),
	}
}

func (m *Manager) SetDirectories(extensionsDir, dataDir string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.extensionsDir = extensionsDir
	m.dataDir = dataDir
	if err := os.MkdirAll(extensionsDir, 0755); err != nil {
		return fmt.Errorf("failed to create extensions directory: %w", err)
	}
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return fmt.Errorf("failed to create data directory: %w", err)
	}
	return nil
}
