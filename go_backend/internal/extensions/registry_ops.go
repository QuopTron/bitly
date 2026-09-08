package extensions

import (
	"os"
	"path/filepath"
	"strings"
	"sync"
)

// ExtensionInfo guarda los metadatos de una extension instalada.
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

// Registry gestiona las extensiones instaladas.
type Registry struct {
	mu         sync.Mutex
	extensions map[string]*ExtensionInfo
	dir        string
	runtime    *Runtime
}

// NewRegistry crea un registro de extensiones con runtime goja.
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

// NewRegistryBestEffort devuelve siempre un registro usable (con runtime goja)
// sin importar la escritura del directorio, para que las extensiones embebidas
// puedan cargar en plataformas restringidas (p. ej. Android cwd = "/" no es
// escribible). Los errores de directorio no son fatales: simplemente no se
// escanean las extensiones en disco.
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

// scan carga todas las extensiones del directorio de extensiones. Soporta
// layout plano (dir/nombre.js) y layout de subdirectorio (dir/nombre/index.js
// + manifest.json), que es como Android distribuye las extensiones.
func (r *Registry) scan() error {
	entries, err := os.ReadDir(r.dir)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() {
			// Layout de subdirectorio: dir/<extID>/index.js
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
		info.Name = info.ID // respaldo
		r.extensions[info.ID] = info
	}
	return nil
}

// List devuelve todas las extensiones instaladas.
func (r *Registry) List() []ExtensionInfo {
	r.mu.Lock()
	defer r.mu.Unlock()
	result := make([]ExtensionInfo, 0, len(r.extensions))
	for _, info := range r.extensions {
		result = append(result, *info)
	}
	return result
}

// Get devuelve una extension por su ID.
func (r *Registry) Get(id string) *ExtensionInfo {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.extensions[id]
}

// Runtime devuelve el runtime de extensiones para ejecutar JS.
func (r *Registry) Runtime() *Runtime {
	return r.runtime
}
