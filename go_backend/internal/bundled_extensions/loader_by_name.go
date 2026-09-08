package bundled_extensions

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

func LoadByName(reg *extensions.Registry, name string) (*RegisteredExtension, error) {
	ext, err := Load(name)
	if err != nil {
		return nil, fmt.Errorf("ERR_BUNDLED_NO_ENCONTRADA: extensión embebida %s no encontrada: %w", name, err)
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
		return nil, fmt.Errorf("ERR_BUNDLED_EJECUCION: no se pudo ejecutar la embebida %s: %w", name, err)
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
