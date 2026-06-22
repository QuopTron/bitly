package manager

import (
	"fmt"
	"os"
)

func copyCapabilities(src map[string]interface{}) map[string]interface{} {
	if src == nil {
		return nil
	}
	dst := make(map[string]interface{}, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}

func (m *Manager) UnloadExtension(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.extensions, id)
	return nil
}

func (m *Manager) GetExtension(id string) (*Extension, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	ext, ok := m.extensions[id]
	if !ok {
		return nil, fmt.Errorf("extension not found: %s", id)
	}
	return ext, nil
}

func (m *Manager) ListExtensions() []*Extension {
	m.mu.RLock()
	defer m.mu.RUnlock()
	result := make([]*Extension, 0, len(m.extensions))
	for _, ext := range m.extensions {
		result = append(result, ext)
	}
	return result
}

func (m *Manager) RemoveExtension(id string) error {
	ext, err := m.GetExtension(id)
	if err != nil {
		return err
	}
	m.UnloadExtension(id)
	if ext.SourceDir != "" {
		os.RemoveAll(ext.SourceDir)
	}
	return nil
}

func (m *Manager) SetExtensionEnabled(id string, enabled bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	ext, ok := m.extensions[id]
	if !ok {
		return fmt.Errorf("extension not found: %s", id)
	}
	ext.Enabled = enabled
	if !enabled {
		ext.Error = ""
	}
	return nil
}
