package cache

import (
	"container/list"
	"sync"
)

// lruEntry holds a key-value pair in the LRU linked list.
type lruEntry[T any] struct {
	key   string
	value T
}

// LRU is a fixed-size LRU cache using container/list + map.
// When full, the least recently used item is evicted.
type LRU[T any] struct {
	mu      sync.Mutex
	maxSize int
	ll      *list.List
	items   map[string]*list.Element
}

// NewLRU creates an LRU cache that holds at most maxSize entries.
// maxSize must be at least 1.
func NewLRU[T any](maxSize int) *LRU[T] {
	if maxSize < 1 {
		maxSize = 1
	}
	return &LRU[T]{
		maxSize: maxSize,
		ll:      list.New(),
		items:   make(map[string]*list.Element),
	}
}

// Get retrieves a value and marks it as recently used.
func (c *LRU[T]) Get(key string) (T, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if elem, ok := c.items[key]; ok {
		c.ll.MoveToFront(elem)
		return elem.Value.(*lruEntry[T]).value, true
	}
	var zero T
	return zero, false
}

// Set stores a value, evicting the oldest entry if at capacity.
func (c *LRU[T]) Set(key string, value T) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if elem, ok := c.items[key]; ok {
		c.ll.MoveToFront(elem)
		elem.Value.(*lruEntry[T]).value = value
		return
	}
	if c.ll.Len() >= c.maxSize {
		back := c.ll.Back()
		if back != nil {
			delete(c.items, back.Value.(*lruEntry[T]).key)
			c.ll.Remove(back)
		}
	}
	elem := c.ll.PushFront(&lruEntry[T]{key: key, value: value})
	c.items[key] = elem
}

// Delete removes a key.
func (c *LRU[T]) Delete(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if elem, ok := c.items[key]; ok {
		c.ll.Remove(elem)
		delete(c.items, key)
	}
}

// Clear removes all entries.
func (c *LRU[T]) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.ll.Init()
	c.items = make(map[string]*list.Element)
}

// Len returns the current number of entries.
func (c *LRU[T]) Len() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.ll.Len()
}
