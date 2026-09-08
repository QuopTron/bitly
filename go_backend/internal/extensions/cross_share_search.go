package extensions

import (
	"sync"
	"time"
)

// CollectionMatch representa una coincidencia encontrada en otra extension.
type CollectionMatch struct {
	ExtensionID  string  `json:"extension_id"`
	CollectionID string  `json:"collection_id"`
	Name         string  `json:"name"`
	CoverURL     string  `json:"cover_url,omitempty"`
	Type         string  `json:"type"`
	Score        float64 `json:"score"`
}

// CrossExtensionShare gestiona el descubrimiento de colecciones entre extensiones.
type CrossExtensionShare struct {
	mu       sync.RWMutex
	cache    map[string]*crossShareCacheEntry
	order    []string
	registry *Registry
}

type crossShareCacheEntry struct {
	results []CollectionMatch
	expires time.Time
}

const crossShareCacheMax = 128

// NewCrossExtensionShare crea un nuevo servicio de comparticion entre extensiones.
func NewCrossExtensionShare(reg *Registry) *CrossExtensionShare {
	return &CrossExtensionShare{
		cache:    make(map[string]*crossShareCacheEntry),
		registry: reg,
	}
}

// FindCollectionAcrossExtensions busca en todos los proveedores de metadatos
// instalados (excepto el origen) la misma album/artista/lista de reproduccion.
func (ces *CrossExtensionShare) FindCollectionAcrossExtensions(
	name string, artists []string, collectionType string, sourceExtensionID string,
) []CollectionMatch {
	if name == "" {
		return nil
	}
	cacheKey := construirClaveCrossShare(name, artists, collectionType, sourceExtensionID)

	ces.mu.RLock()
	if entry, ok := ces.cache[cacheKey]; ok && time.Now().Before(entry.expires) {
		ces.mu.RUnlock()
		return entry.results
	}
	ces.mu.RUnlock()

	// Search across extensions in parallel
	extensions := ces.registry.List()
	if len(extensions) == 0 {
		return nil
	}

	type sr struct{ matches []CollectionMatch }
	results := make(chan sr, len(extensions))
	var wg sync.WaitGroup

	for _, ext := range extensions {
		if ext.ID == sourceExtensionID || !ext.Enabled {
			continue
		}
		wg.Add(1)
		go func(id string) {
			defer wg.Done()
			m := ces.searchExtension(id, name, collectionType)
			if len(m) > 0 {
				results <- sr{m}
			}
		}(ext.ID)
	}

	go func() { wg.Wait(); close(results) }()

	var all []CollectionMatch
	for r := range results {
		all = append(all, r.matches...)
	}

	ranked := ces.rankMatches(name, all)

	ces.mu.Lock()
	if len(ces.order) >= crossShareCacheMax {
		delete(ces.cache, ces.order[0])
		ces.order = ces.order[1:]
	}
	ces.cache[cacheKey] = &crossShareCacheEntry{results: ranked, expires: time.Now().Add(5 * time.Minute)}
	ces.order = append(ces.order, cacheKey)
	ces.mu.Unlock()

	return ranked
}

func (ces *CrossExtensionShare) searchExtension(extID, name, ctype string) []CollectionMatch {
	ext := ces.registry.Get(extID)
	if ext == nil || !ext.Enabled {
		return nil
	}

	// Extension found, would search via runtime
	// For now return empty - actual search is done via JS runtime
	_ = name
	_ = ctype
	return nil
}
