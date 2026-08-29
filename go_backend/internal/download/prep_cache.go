package download

import (
	"sync"
	"time"
)

// ═══════════════════════════════════════════════════════════════════════
// Download Preparation Cache — cache metadata preparation results
// ═══════════════════════════════════════════════════════════════════════

type prepCacheEntry struct {
	request   Request
	prepared  bool
	expiresAt time.Time
}

// PrepCache caches metadata preparation results to avoid redundant resolution.
type PrepCache struct {
	mu      sync.Mutex
	entries map[string]*prepCacheEntry
	order   []string
}

const (
	prepCacheMax    = 128
	prepCacheTTL    = 5 * time.Minute
)

// NewPrepCache creates a new preparation cache.
func NewPrepCache() *PrepCache {
	return &PrepCache{entries: make(map[string]*prepCacheEntry)}
}

func prepCacheKey(r Request) string {
	if r.ISRC != "" {
		return "isrc:" + r.ISRC
	}
	if r.TrackID != "" {
		return "track:" + r.TrackID
	}
	return "name:" + r.Title + "|" + r.Artist
}

// CachePreparedDownloadRequest stores a prepared download request.
func (pc *PrepCache) CachePreparedDownloadRequest(r Request) {
	pc.mu.Lock()
	defer pc.mu.Unlock()

	key := prepCacheKey(r)
	if len(pc.order) >= prepCacheMax {
		delete(pc.entries, pc.order[0])
		pc.order = pc.order[1:]
	}
	pc.entries[key] = &prepCacheEntry{
		request:   r,
		prepared:  true,
		expiresAt: time.Now().Add(prepCacheTTL),
	}
	pc.order = append(pc.order, key)
}

// TakePreparedDownloadRequest retrieves and removes a cached prepared request.
func (pc *PrepCache) TakePreparedDownloadRequest(r Request) (*Request, bool) {
	pc.mu.Lock()
	defer pc.mu.Unlock()

	key := prepCacheKey(r)
	entry, ok := pc.entries[key]
	if !ok || time.Now().After(entry.expiresAt) {
		if ok {
			delete(pc.entries, key)
		}
		return nil, false
	}

	// Transfer metadata from prepared to fresh request
	result := r
	prep := entry.request
	if prep.ISRC != "" {
		result.ISRC = prep.ISRC
	}
	if prep.SpotifyID != "" {
		result.SpotifyID = prep.SpotifyID
	}
	if prep.DeezerID != "" {
		result.DeezerID = prep.DeezerID
	}
	if prep.TidalID != "" {
		result.TidalID = prep.TidalID
	}
	if prep.QobuzID != "" {
		result.QobuzID = prep.QobuzID
	}
	if prep.Title != "" && result.Title == "" {
		result.Title = prep.Title
	}
	if prep.Artist != "" && result.Artist == "" {
		result.Artist = prep.Artist
	}
	if prep.Album != "" && result.Album == "" {
		result.Album = prep.Album
	}

	// Remove from cache
	delete(pc.entries, key)
	return &result, true
}

// Clear removes all cached entries.
func (pc *PrepCache) Clear() {
	pc.mu.Lock()
	defer pc.mu.Unlock()
	pc.entries = make(map[string]*prepCacheEntry)
	pc.order = nil
}

// Len returns the number of cached entries.
func (pc *PrepCache) Len() int {
	pc.mu.Lock()
	defer pc.mu.Unlock()
	return len(pc.entries)
}
