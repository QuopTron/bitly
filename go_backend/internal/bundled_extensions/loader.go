package bundled_extensions

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// RegisteredExtension holds info about a successfully loaded bundled extension.
type RegisteredExtension struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Version string `json:"version"`
	Type    string `json:"type"` // "metadata", "download", "both"
	Enabled bool   `json:"enabled"`
}

// LoadAllToRegistry loads all bundled extensions into the provided registry
// and returns the list of successfully registered extensions.
func LoadAllToRegistry(reg *extensions.Registry) []RegisteredExtension {
	dirs, err := List()
	if err != nil {
		return nil
	}

	list := make([]RegisteredExtension, 0, len(dirs))
	cfg := extensions.DefaultConfig()
	cfg.EnableFS = true
	cfg.AllowedDirs = []string{"."}

	for _, dir := range dirs {
		ext, err := Load(dir)
		if err != nil {
			continue
		}

		// Parse manifest for metadata
		var manifest struct {
			Name        string   `json:"name"`
			DisplayName string   `json:"displayName"`
			Version     string   `json:"version"`
			Type        []string `json:"type"`
		}
		if err := json.Unmarshal(ext.ManifestData, &manifest); err != nil {
			manifest.Name = dir
			manifest.Version = "0.0.0"
		}
		if manifest.Name == "" {
			manifest.Name = dir
		}

		extType := "both"
		if len(manifest.Type) == 1 {
			extType = manifest.Type[0]
		} else if len(manifest.Type) == 0 {
			extType = "metadata"
		}

		// Run the extension JS in sandbox
		_, err = reg.Runtime().RunJS(
			string(ext.IndexJSData),
			dir,
			manifest.Name,
			cfg,
			".",
		)
		if err != nil {
			_ = err // silently skip failed extensions
			continue
		}

		list = append(list, RegisteredExtension{
			ID:      dir,
			Name:    manifest.DisplayName,
			Version: manifest.Version,
			Type:    extType,
			Enabled: true,
		})
	}

	return list
}

// LoadByName loads a specific bundled extension by name into the registry.
func LoadByName(reg *extensions.Registry, name string) (*RegisteredExtension, error) {
	ext, err := Load(name)
	if err != nil {
		return nil, fmt.Errorf("bundled extension %s not found: %w", name, err)
	}

	var manifest struct {
		Name        string   `json:"name"`
		DisplayName string   `json:"displayName"`
		Version     string   `json:"version"`
		Type        []string `json:"type"`
	}
	if err := json.Unmarshal(ext.ManifestData, &manifest); err != nil {
		manifest.Name = name
		manifest.Version = "0.0.0"
	}
	if manifest.Name == "" {
		manifest.Name = name
	}

	cfg := extensions.DefaultConfig()
	cfg.EnableFS = true

	_, err = reg.Runtime().RunJS(
		string(ext.IndexJSData),
		name,
		manifest.Name,
		cfg,
		".",
	)
	if err != nil {
		return nil, fmt.Errorf("run bundled %s: %w", name, err)
	}

	extType := "both"
	if len(manifest.Type) == 1 {
		extType = manifest.Type[0]
	}

	return &RegisteredExtension{
		ID:      name,
		Name:    manifest.DisplayName,
		Version: manifest.Version,
		Type:    extType,
		Enabled: true,
	}, nil
}
