package cache

import "time"

// CoverCache caches cover art byte slices in memory with TTL.
// Covers are typically 10-500 KB and can be served without re-downloading.
type CoverCache struct {
	store *Cache[[]byte]
}

// NewCoverCache creates a cover cache with the given TTL.
// Default cleanup runs every 5 minutes.
func NewCoverCache(ttl time.Duration) *CoverCache {
	return &CoverCache{
		store: New[[]byte](ttl, 5*time.Minute),
	}
}

// Get returns cached cover data for a key (typically provider:albumID).
func (cc *CoverCache) Get(key string) ([]byte, bool) {
	return cc.store.Get(key)
}

// Set stores cover data under a key.
func (cc *CoverCache) Set(key string, data []byte) {
	cc.store.Set(key, data)
}

// Has returns true if the key exists and is not expired.
func (cc *CoverCache) Has(key string) bool {
	return cc.store.Has(key)
}

// Delete removes a cached cover.
func (cc *CoverCache) Delete(key string) {
	cc.store.Delete(key)
}

// Clear removes all cached covers.
func (cc *CoverCache) Clear() {
	cc.store.Clear()
}

// Close stops the background cleanup goroutine.
func (cc *CoverCache) Close() {
	cc.store.Close()
}
