package availability

import (
	"sync"
	"time"
)

type cacheEntry struct {
	result   []AvailabilityResult
	expireAt time.Time
}

// Cache caches availability check results.
type Cache struct {
	mu       sync.RWMutex
	entries  map[string]cacheEntry
	ttl      time.Duration
	maxSize  int
}

// NewCache creates an availability cache.
func NewCache(ttl time.Duration, maxSize int) *Cache {
	return &Cache{
		entries: make(map[string]cacheEntry),
		ttl:     ttl,
		maxSize: maxSize,
	}
}

// Get retrieves a cached result.
func (c *Cache) Get(key string) ([]AvailabilityResult, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	entry, ok := c.entries[key]
	if !ok || time.Now().After(entry.expireAt) {
		return nil, false
	}
	return entry.result, true
}

// Set stores a result in the cache.
func (c *Cache) Set(key string, result []AvailabilityResult) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(c.entries) >= c.maxSize {
		for k := range c.entries {
			delete(c.entries, k)
			break
		}
	}
	c.entries[key] = cacheEntry{
		result:   result,
		expireAt: time.Now().Add(c.ttl),
	}
}

// Clear empties the cache.
func (c *Cache) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.entries = make(map[string]cacheEntry)
}
