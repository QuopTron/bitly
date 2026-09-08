package extensions

import (
	"time"
)

func (es *ExtensionStore) ClearCache() {
	es.mu.Lock()
	defer es.mu.Unlock()
	es.cache = nil
	es.cacheExpiry = time.Time{}
}

// GetInstalledVersions returns the map of installed extension versions.
func (es *ExtensionStore) GetInstalledVersions() map[string]string {
	es.mu.RLock()
	defer es.mu.RUnlock()
	result := make(map[string]string, len(es.installed))
	for k, v := range es.installed {
		result[k] = v
	}
	return result
}

// MarkInstalled records that an extension version is installed.
func (es *ExtensionStore) MarkInstalled(id, version string) {
	es.mu.Lock()
	defer es.mu.Unlock()
	es.installed[id] = version
}
