package manager

import "github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"

// RegisterExtensionFromData registers an extension from manifest data without
// requiring a filesystem path. This is used for embedded/bundled extensions
// where the JS source comes from a go:embed byte slice rather than disk.
//
// The extension is registered as disabled by default and with no source dir,
// since the JS runtime will load directly from data.
func (m *Manager) RegisterExtensionFromData(id string, mf *manifest.ExtensionManifest) (*Extension, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if existing, exists := m.extensions[id]; exists {
		return existing, nil
	}

	return m.registerExtension(mf, "", "", false), nil
}
