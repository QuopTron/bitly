package extensions

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Install copia un archivo JS al directorio de extensiones y lo registra.
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

// Remove elimina una extension del disco y del registro.
func (r *Registry) Remove(id string) error {
	info := r.Get(id)
	if info == nil {
		return fmt.Errorf("ERR_EXTENSION: la extension %s no existe", id)
	}
	if err := os.Remove(info.Path); err != nil {
		return err
	}
	r.mu.Lock()
	delete(r.extensions, id)
	r.mu.Unlock()
	return nil
}
