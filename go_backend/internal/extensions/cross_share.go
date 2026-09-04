package extensions

import (
	"strings"
	"sync"
	"time"
)

// CollectionMatch represents a match found in another extension.
type CollectionMatch struct {
	ExtensionID  string  `json:"extension_id"`
	CollectionID string  `json:"collection_id"`
	Name         string  `json:"name"`
	CoverURL     string  `json:"cover_url,omitempty"`
	Type         string  `json:"type"`
	Score        float64 `json:"score"`
}

// CrossExtensionShare manages cross-extension collection discovery.
type CrossExtensionShare struct {
	mu      sync.RWMutex
	cache   map[string]*crossShareCacheEntry
	order   []string
	registry *Registry
}

type crossShareCacheEntry struct {
	results []CollectionMatch
	expires time.Time
}

const crossShareCacheMax = 128

// NewCrossExtensionShare creates a new cross-extension sharing service.
func NewCrossExtensionShare(reg *Registry) *CrossExtensionShare {
	return &CrossExtensionShare{
		cache:    make(map[string]*crossShareCacheEntry),
		registry: reg,
	}
}

// FindCollectionAcrossExtensions searches all installed metadata providers
// (except the source) to find the same album/artist/playlist.
func (ces *CrossExtensionShare) FindCollectionAcrossExtensions(
	name string, artists []string, collectionType string, sourceExtensionID string,
) []CollectionMatch {
	if name == "" {
		return nil
	}
	cacheKey := buildCrossShareKey(name, artists, collectionType, sourceExtensionID)

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

func (ces *CrossExtensionShare) rankMatches(query string, matches []CollectionMatch) []CollectionMatch {
	for i := range matches {
		matches[i].Score *= titleBoost(query, matches[i].Name)
	}
	for i := 1; i < len(matches); i++ {
		for j := i; j > 0 && matches[j].Score > matches[j-1].Score; j-- {
			matches[j], matches[j-1] = matches[j-1], matches[j]
		}
	}
	return matches
}

func titleBoost(query, candidate string) float64 {
	q := strings.ToLower(strings.TrimSpace(query))
	c := strings.ToLower(strings.TrimSpace(candidate))
	if q == c {
		return 1.2
	}
	if strings.Contains(c, q) || strings.Contains(q, c) {
		return 1.0
	}
	return 0.8
}

func buildCrossShareKey(name string, artists []string, ctype, source string) string {
	return strings.ToLower(name) + "|" + strings.Join(artists, ",") + "|" + ctype + "|" + source
}

// ClearCache removes all cached cross-extension results.
func (ces *CrossExtensionShare) ClearCache() {
	ces.mu.Lock()
	defer ces.mu.Unlock()
	ces.cache = make(map[string]*crossShareCacheEntry)
	ces.order = nil
}
