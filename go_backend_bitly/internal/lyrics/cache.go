package lyrics

import (
	"fmt"
	"math"
	"strings"
	"sync"
	"time"
)

const lyricsCacheTTL = 24 * time.Hour

type lyricsCacheEntry struct {
	response  *LyricsResponse
	expiresAt time.Time
}

// lyricsCache is a thread-safe in-memory cache for lyrics responses.
type lyricsCache struct {
	mu    sync.RWMutex
	cache map[string]*lyricsCacheEntry
}

var globalLyricsCache = &lyricsCache{
	cache: make(map[string]*lyricsCacheEntry),
}

func (c *lyricsCache) generateKey(artist, track string, durationSec float64) string {
	normalizedArtist := strings.ToLower(strings.TrimSpace(artist))
	normalizedTrack := strings.ToLower(strings.TrimSpace(track))
	roundedDuration := math.Round(durationSec/10) * 10
	return fmt.Sprintf("%s|%s|%.0f", normalizedArtist, normalizedTrack, roundedDuration)
}

// Get retrieves cached lyrics, nil if not found or expired.
func (c *lyricsCache) Get(artist, track string, durationSec float64) (*LyricsResponse, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	key := c.generateKey(artist, track, durationSec)
	entry, exists := c.cache[key]
	if !exists || time.Now().After(entry.expiresAt) {
		return nil, false
	}
	return entry.response, true
}

// Set stores lyrics in the cache with the default TTL.
func (c *lyricsCache) Set(artist, track string, durationSec float64, response *LyricsResponse) {
	c.mu.Lock()
	defer c.mu.Unlock()

	key := c.generateKey(artist, track, durationSec)
	c.cache[key] = &lyricsCacheEntry{
		response:  response,
		expiresAt: time.Now().Add(lyricsCacheTTL),
	}
}

// CleanExpired removes expired entries and returns the count.
func (c *lyricsCache) CleanExpired() int {
	c.mu.Lock()
	defer c.mu.Unlock()

	now := time.Now()
	cleaned := 0
	for key, entry := range c.cache {
		if now.After(entry.expiresAt) {
			delete(c.cache, key)
			cleaned++
		}
	}
	return cleaned
}

// Size returns the number of entries in the cache.
func (c *lyricsCache) Size() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return len(c.cache)
}

// ClearAll removes all cached entries.
func (c *lyricsCache) ClearAll() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	cleared := len(c.cache)
	c.cache = make(map[string]*lyricsCacheEntry)
	return cleared
}
