package search

import (
	"sync"
	"time"
)

type searchCacheEntry struct {
	result *SearchResult
	expiry time.Time
}

// Cache caches search results to avoid redundant network calls.
type Cache struct {
	mu      sync.RWMutex
	entries map[string]searchCacheEntry
	ttl     time.Duration
	maxSize int
}

// NewCache creates a search result cache.
func NewCache(ttl time.Duration, maxSize int) *Cache {
	return &Cache{
		entries: make(map[string]searchCacheEntry),
		ttl:     ttl,
		maxSize: maxSize,
	}
}

// Get retrieves a cached search result.
func (c *Cache) Get(key string) (*SearchResult, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	entry, ok := c.entries[key]
	if !ok || time.Now().After(entry.expiry) {
		return nil, false
	}
	return entry.result, true
}

// Set caches a search result.
func (c *Cache) Set(key string, result *SearchResult) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(c.entries) >= c.maxSize {
		for k := range c.entries {
			delete(c.entries, k)
			break
		}
	}
	c.entries[key] = searchCacheEntry{
		result: result,
		expiry: time.Now().Add(c.ttl),
	}
}
