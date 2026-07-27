// Package cache provides in-memory caching with TTL, LRU eviction,
// and specialized caches for covers, search results, and ISRC dedup.
//
// Usage:
//
//	c := cache.New[string](5*time.Minute, time.Minute)
//	c.Set("key", "value")
//	v, ok := c.Get("key")
package cache

import (
	"sync"
	"time"
)

// item holds a cached value with an optional expiration.
type item[T any] struct {
	value   T
	expires time.Time
}

// Cache is a generic TTL cache with automatic cleanup.
type Cache[T any] struct {
	mu          sync.RWMutex
	items       map[string]item[T]
	defaultTTL  time.Duration
	stopCh      chan struct{}
	stopped     bool
}

// New creates a Cache. If cleanupInterval > 0 a background goroutine
// removes expired entries at that interval. Pass 0 to disable cleanup.
func New[T any](defaultTTL, cleanupInterval time.Duration) *Cache[T] {
	c := &Cache[T]{
		items:      make(map[string]item[T]),
		defaultTTL: defaultTTL,
		stopCh:     make(chan struct{}),
	}
	if cleanupInterval > 0 {
		go c.cleanup(cleanupInterval)
	}
	return c
}

// Get returns a value from the cache. The bool is false if missing or expired.
func (c *Cache[T]) Get(key string) (T, bool) {
	c.mu.RLock()
	it, ok := c.items[key]
	c.mu.RUnlock()
	if !ok {
		var zero T
		return zero, false
	}
	if !it.expires.IsZero() && time.Now().After(it.expires) {
		c.Delete(key)
		var zero T
		return zero, false
	}
	return it.value, true
}

// Set stores a value with the default TTL. Pass a positive duration to
// override the TTL for this specific item.
func (c *Cache[T]) Set(key string, value T, ttl ...time.Duration) {
	var expires time.Time
	if len(ttl) > 0 && ttl[0] > 0 {
		expires = time.Now().Add(ttl[0])
	} else if c.defaultTTL > 0 {
		expires = time.Now().Add(c.defaultTTL)
	}
	c.mu.Lock()
	c.items[key] = item[T]{value: value, expires: expires}
	c.mu.Unlock()
}

// Has returns true if the key exists and is not expired.
func (c *Cache[T]) Has(key string) bool {
	c.mu.RLock()
	it, ok := c.items[key]
	c.mu.RUnlock()
	if !ok {
		return false
	}
	if !it.expires.IsZero() && time.Now().After(it.expires) {
		c.Delete(key)
		return false
	}
	return true
}

// Delete removes a key from the cache.
func (c *Cache[T]) Delete(key string) {
	c.mu.Lock()
	delete(c.items, key)
	c.mu.Unlock()
}

// Clear removes all entries.
func (c *Cache[T]) Clear() {
	c.mu.Lock()
	c.items = make(map[string]item[T])
	c.mu.Unlock()
}

// Len returns the number of entries (including expired ones not yet cleaned).
func (c *Cache[T]) Len() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return len(c.items)
}

// Close stops the background cleanup goroutine.
func (c *Cache[T]) Close() {
	c.mu.Lock()
	if c.stopped {
		c.mu.Unlock()
		return
	}
	c.stopped = true
	c.mu.Unlock()
	close(c.stopCh)
}

// cleanup runs in a goroutine, removing expired entries periodically.
func (c *Cache[T]) cleanup(interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			now := time.Now()
			c.mu.Lock()
			for k, it := range c.items {
				if !it.expires.IsZero() && now.After(it.expires) {
					delete(c.items, k)
				}
			}
			c.mu.Unlock()
		case <-c.stopCh:
			return
		}
	}
}
