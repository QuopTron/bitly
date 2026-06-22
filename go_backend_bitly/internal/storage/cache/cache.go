package cache

import (
	"container/list"
	"sync"
	"time"
)

// Entry is a cache entry with expiration.
type Entry struct {
	Key       string
	Value     interface{}
	ExpiresAt time.Time
}

// Cache is a generic LRU cache with TTL.
type Cache struct {
	mu       sync.RWMutex
	entries  map[string]*list.Element
	lru      *list.List
	maxSize  int
	defaultTTL time.Duration
}

// NewCache creates a new cache.
func NewCache(maxSize int, defaultTTL time.Duration) *Cache {
	return &Cache{
		entries:    make(map[string]*list.Element),
		lru:        list.New(),
		maxSize:    maxSize,
		defaultTTL: defaultTTL,
	}
}

// Get retrieves a value from cache.
func (c *Cache) Get(key string) (interface{}, bool) {
	c.mu.RLock()
	elem, ok := c.entries[key]
	if !ok {
		c.mu.RUnlock()
		return nil, false
	}
	entry := elem.Value.(*Entry)
	if time.Now().After(entry.ExpiresAt) {
		c.mu.RUnlock()
		return nil, false
	}
	c.mu.RUnlock()

	c.mu.Lock()
	c.lru.MoveToFront(elem)
	c.mu.Unlock()
	return entry.Value, true
}

// Set adds a value to cache with the default TTL.
func (c *Cache) Set(key string, value interface{}) {
	c.SetWithTTL(key, value, c.defaultTTL)
}

// SetWithTTL adds a value with a specific TTL.
func (c *Cache) SetWithTTL(key string, value interface{}, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if elem, ok := c.entries[key]; ok {
		c.lru.MoveToFront(elem)
		elem.Value.(*Entry).Value = value
		elem.Value.(*Entry).ExpiresAt = time.Now().Add(ttl)
		return
	}

	entry := &Entry{
		Key:       key,
		Value:     value,
		ExpiresAt: time.Now().Add(ttl),
	}
	elem := c.lru.PushFront(entry)
	c.entries[key] = elem

	if c.lru.Len() > c.maxSize {
		c.removeOldest()
	}
}

// Delete removes a key from cache.
func (c *Cache) Delete(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if elem, ok := c.entries[key]; ok {
		c.lru.Remove(elem)
		delete(c.entries, key)
	}
}

// Clear empties the cache.
func (c *Cache) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.entries = make(map[string]*list.Element)
	c.lru.Init()
}

// Size returns the number of items in cache.
func (c *Cache) Size() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return len(c.entries)
}

func (c *Cache) removeOldest() {
	elem := c.lru.Back()
	if elem != nil {
		c.lru.Remove(elem)
		delete(c.entries, elem.Value.(*Entry).Key)
	}
}
