// Package extensions manages JS extension loading, runtime, and API.
package extensions

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

// ExtensionInfo holds metadata about an installed extension.
type ExtensionInfo struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Version     string `json:"version"`
	Description string `json:"description"`
	Author      string `json:"author"`
	Provider    string `json:"provider"` // deezer, qobuz, tidal, etc.
	Enabled     bool   `json:"enabled"`
	Path        string `json:"path"`
}

// Registry manages installed extensions.
type Registry struct {
	mu         sync.Mutex
	extensions map[string]*ExtensionInfo
	dir        string
	runtime    *Runtime
}

// NewRegistry creates an extension registry with a goja runtime.
func NewRegistry(extensionsDir string) (*Registry, error) {
	reg := &Registry{
		extensions: make(map[string]*ExtensionInfo),
		dir:        extensionsDir,
		runtime:    NewRuntime(),
	}
	if err := os.MkdirAll(extensionsDir, 0755); err != nil {
		return nil, err
	}
	if err := reg.scan(); err != nil {
		return nil, err
	}
	return reg, nil
}

// NewRegistryBestEffort always returns a usable registry (with a goja runtime)
// regardless of directory writability, so embedded extensions can always load
// on constrained platforms (e.g. Android cwd = "/" is not writable). Directory
// errors are non-fatal: on-disk extensions simply aren't scanned.
func NewRegistryBestEffort(extensionsDir string) *Registry {
	reg := &Registry{
		extensions: make(map[string]*ExtensionInfo),
		dir:        extensionsDir,
		runtime:    NewRuntime(),
	}
	_ = os.MkdirAll(extensionsDir, 0o755)
	_ = reg.scan()
	return reg
}

// scan loads all extensions from the extensions directory.
// Supports both flat layout (dir/name.js) and subdirectory layout
// (dir/name/index.js + manifest.json), which is how Android ships extensions.
func (r *Registry) scan() error {
	entries, err := os.ReadDir(r.dir)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() {
			// Subdirectory layout: dir/<extID>/index.js
			indexPath := filepath.Join(r.dir, entry.Name(), "index.js")
			if _, err := os.Stat(indexPath); err != nil {
				continue
			}
			info := &ExtensionInfo{
				ID:      entry.Name(),
				Path:    indexPath,
				Enabled: true,
				Name:    entry.Name(),
			}
			r.extensions[info.ID] = info
			continue
		}
		if filepath.Ext(entry.Name()) != ".js" {
			continue
		}
		info := &ExtensionInfo{
			ID:      strings.TrimSuffix(entry.Name(), ".js"),
			Path:    filepath.Join(r.dir, entry.Name()),
			Enabled: true,
		}
		info.Name = info.ID // fallback
		r.extensions[info.ID] = info
	}
	return nil
}

// List returns all installed extensions.
func (r *Registry) List() []ExtensionInfo {
	r.mu.Lock()
	defer r.mu.Unlock()
	result := make([]ExtensionInfo, 0, len(r.extensions))
	for _, info := range r.extensions {
		result = append(result, *info)
	}
	return result
}

// Get returns an extension by ID.
func (r *Registry) Get(id string) *ExtensionInfo {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.extensions[id]
}

// Install copies a JS file into the extensions directory.
func (r *Registry) Install(sourcePath string) (*ExtensionInfo, error) {
	data, err := os.ReadFile(sourcePath)
	if err != nil {
		return nil, err
	}
	id := strings.TrimSuffix(filepath.Base(sourcePath), ".js")
	destPath := filepath.Join(r.dir, id+".js")

	if err := os.WriteFile(destPath, data, 0644); err != nil {
		return nil, err
	}

	info := &ExtensionInfo{
		ID:      id,
		Path:    destPath,
		Enabled: true,
		Name:    id,
	}

	r.mu.Lock()
	r.extensions[id] = info
	r.mu.Unlock()
	return info, nil
}

// Runtime returns the extension runtime for executing JS.
func (r *Registry) Runtime() *Runtime {
	return r.runtime
}

// Remove deletes an extension.
func (r *Registry) Remove(id string) error {
	info := r.Get(id)
	if info == nil {
		return fmt.Errorf("extension %s not found", id)
	}
	if err := os.Remove(info.Path); err != nil {
		return err
	}
	r.mu.Lock()
	delete(r.extensions, id)
	r.mu.Unlock()
	return nil
}
