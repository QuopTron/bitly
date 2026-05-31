package gobackend

import (
	"container/list"
	"encoding/json"
	"fmt"
	"sync"
	"time"
)

type lruCacheEntry struct {
	data      interface{}
	expiresAt time.Time
	key       string
}

type LRUCache struct {
	mu       sync.RWMutex
	items    map[string]*list.Element
	order    *list.List
	maxSize  int
	defaultTTL time.Duration
	hits     int64
	misses   int64
}

func NewLRUCache(maxSize int, defaultTTL time.Duration) *LRUCache {
	return &LRUCache{
		items:      make(map[string]*list.Element),
		order:      list.New(),
		maxSize:    maxSize,
		defaultTTL: defaultTTL,
	}
}

func (c *LRUCache) Get(key string) (interface{}, bool) {
	c.mu.RLock()
	elem, ok := c.items[key]
	c.mu.RUnlock()
	if !ok {
		return nil, false
	}
	entry := elem.Value.(*lruCacheEntry)
	if time.Now().After(entry.expiresAt) {
		c.mu.Lock()
		c.removeElement(elem)
		c.mu.Unlock()
		return nil, false
	}
	c.mu.Lock()
	c.order.MoveToFront(elem)
	c.hits++
	c.mu.Unlock()
	return entry.data, true
}

func (c *LRUCache) Set(key string, data interface{}, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if elem, ok := c.items[key]; ok {
		c.order.MoveToFront(elem)
		elem.Value.(*lruCacheEntry).data = data
		elem.Value.(*lruCacheEntry).expiresAt = time.Now().Add(ttl)
		return
	}

	if c.order.Len() >= c.maxSize {
		oldest := c.order.Back()
		if oldest != nil {
			c.removeElement(oldest)
		}
	}

	entry := &lruCacheEntry{
		data:      data,
		expiresAt: time.Now().Add(ttl),
		key:       key,
	}
	elem := c.order.PushFront(entry)
	c.items[key] = elem
}

func (c *LRUCache) Len() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.order.Len()
}

func (c *LRUCache) removeElement(elem *list.Element) {
	c.order.Remove(elem)
	entry := elem.Value.(*lruCacheEntry)
	delete(c.items, entry.key)
}

func (c *LRUCache) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.items = make(map[string]*list.Element)
	c.order.Init()
}

func (c *LRUCache) StatsJSON() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	total := c.hits + c.misses
	ratio := 0.0
	if total > 0 {
		ratio = float64(c.hits) / float64(total) * 100
	}
	m := map[string]interface{}{
		"size":     c.order.Len(),
		"max_size": c.maxSize,
		"hits":     c.hits,
		"misses":   c.misses,
		"hit_rate": ratio,
	}
	b, _ := json.Marshal(m)
	return string(b)
}

type PreloadCache struct {
	streamCache *LRUCache
	metaCache   *LRUCache
}

var (
	preloadCache     *PreloadCache
	preloadCacheOnce sync.Once
)

func GetPreloadCache() *PreloadCache {
	preloadCacheOnce.Do(func() {
		preloadCache = &PreloadCache{
			streamCache: NewLRUCache(200, 30*time.Minute),
			metaCache:   NewLRUCache(500, 1*time.Hour),
		}
	})
	return preloadCache
}

func (pc *PreloadCache) GetStreamURL(trackID string) (string, error) {
	v, ok := pc.streamCache.Get("stream:" + trackID)
	if !ok {
		return "", fmt.Errorf("stream not cached: %s", trackID)
	}
	s, _ := v.(string)
	return s, nil
}

func (pc *PreloadCache) SetStreamURL(trackID, streamURL string) {
	pc.streamCache.Set("stream:"+trackID, streamURL, 30*time.Minute)
}

func (pc *PreloadCache) GetMetadata(trackID string) (interface{}, error) {
	v, ok := pc.metaCache.Get("meta:" + trackID)
	if !ok {
		return nil, fmt.Errorf("metadata not cached: %s", trackID)
	}
	return v, nil
}

func (pc *PreloadCache) SetMetadata(trackID string, data interface{}) {
	pc.metaCache.Set("meta:"+trackID, data, 1*time.Hour)
}

func (pc *PreloadCache) WarmStream(trackID, trackName, artistName string, fetchFn func(string, string) (string, error)) {
	if _, err := pc.GetStreamURL(trackID); err == nil {
		return
	}
	url, err := fetchFn(trackName, artistName)
	if err == nil && url != "" {
		pc.SetStreamURL(trackID, url)
	}
}

func (pc *PreloadCache) ClearTrack(trackID string) {
	pc.streamCache.Set("stream:"+trackID, nil, 0)
	pc.metaCache.Set("meta:"+trackID, nil, 0)
}

func (pc *PreloadCache) StatsJSON() string {
	return `{"stream":` + pc.streamCache.StatsJSON() + `,"meta":` + pc.metaCache.StatsJSON() + `}`
}