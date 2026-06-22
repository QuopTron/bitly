package qobuz

import (
	"net/http"
	"sync"
	"time"
)

const (
	baseURL = "https://qobuz.kennyy.com.br/api"
	name    = "qobuz_kennyy"

	searchCacheTTL   = 5 * time.Minute
	albumCacheTTL    = 30 * time.Minute
	artistCacheTTL   = 30 * time.Minute
	downloadCacheTTL = 2 * time.Minute

	maxCacheEntries = 500
)

type cacheEntry struct {
	data      interface{}
	expiresAt time.Time
}

type Client struct {
	httpClient    *http.Client
	cache         map[string]*cacheEntry
	mu            sync.RWMutex
	cleanupTicker *time.Ticker
	stopCleanup   chan struct{}
}

var (
	globalClient     *Client
	globalClientOnce sync.Once
)

func GetClient() *Client {
	globalClientOnce.Do(func() {
		c := &Client{
			httpClient:  &http.Client{Timeout: 15 * time.Second},
			cache:       make(map[string]*cacheEntry),
			stopCleanup: make(chan struct{}),
		}
		c.cleanupTicker = time.NewTicker(5 * time.Minute)
		go c.cleanupLoop()
		globalClient = c
	})
	return globalClient
}

func (c *Client) cleanupLoop() {
	for {
		select {
		case <-c.cleanupTicker.C:
			c.mu.Lock()
			now := time.Now()
			for k, v := range c.cache {
				if now.After(v.expiresAt) {
					delete(c.cache, k)
				}
			}
			for len(c.cache) > maxCacheEntries {
				var oldestKey string
				var oldestTime time.Time
				first := true
				for k, v := range c.cache {
					if first || v.expiresAt.Before(oldestTime) {
						oldestKey = k
						oldestTime = v.expiresAt
						first = false
					}
				}
				delete(c.cache, oldestKey)
			}
			c.mu.Unlock()
		case <-c.stopCleanup:
			return
		}
	}
}

func (c *Client) getFromCache(key string) interface{} {
	c.mu.RLock()
	defer c.mu.RUnlock()
	entry, ok := c.cache[key]
	if !ok || time.Now().After(entry.expiresAt) {
		return nil
	}
	return entry.data
}

func (c *Client) setCache(key string, data interface{}, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.cache[key] = &cacheEntry{data: data, expiresAt: time.Now().Add(ttl)}
	for len(c.cache) > maxCacheEntries {
		var oldestKey string
		var oldestTime time.Time
		first := true
		for k, v := range c.cache {
			if first || v.expiresAt.Before(oldestTime) {
				oldestKey = k
				oldestTime = v.expiresAt
				first = false
			}
		}
		delete(c.cache, oldestKey)
	}
}
