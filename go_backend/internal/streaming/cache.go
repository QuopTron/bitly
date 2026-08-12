// Package streaming provides audio streaming capabilities
// for serving audio to Flutter's media player.
package streaming

import (
	"strconv"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cache"
)

var chunkSize = 256 * 1024 // 256KB chunks (configurable via SetChunkSize)

// SetChunkSize overrides the streaming chunk size (bytes). Clamped to a sane range.
func SetChunkSize(bytes int) {
	if bytes < 32*1024 {
		bytes = 32 * 1024
	}
	chunkSize = bytes
}

// Chunk holds a streamed audio segment.
type Chunk struct {
	Data     []byte `json:"data"`
	Index    int    `json:"index"`
	Size     int    `json:"size"`
	IsLast   bool   `json:"isLast"`
}

// Cache caches streamed audio chunks in memory for playback.
type Cache struct {
	store       *cache.Cache[[]byte]
	mu          sync.Mutex
	trackChunks map[string]int // trackURL → chunk count
}

// NewCache creates a streaming cache with 5-minute TTL.
func NewCache() *Cache {
	return &Cache{
		store:       cache.New[[]byte](5*time.Minute, time.Minute),
		trackChunks: make(map[string]int),
	}
}

// Add stores a chunk for a track.
func (sc *Cache) Add(trackURL string, chunk Chunk) {
	key := trackURL + ":chunk:" + strconv.Itoa(chunk.Index)
	sc.store.Set(key, chunk.Data)
	sc.mu.Lock()
	sc.trackChunks[trackURL] = chunk.Index + 1
	sc.mu.Unlock()
}

// Get retrieves a chunk for a track.
func (sc *Cache) Get(trackURL string, index int) ([]byte, bool) {
	return sc.store.Get(trackURL + ":chunk:" + strconv.Itoa(index))
}

// ChunkCount returns the number of chunks cached for a track.
func (sc *Cache) ChunkCount(trackURL string) int {
	sc.mu.Lock()
	defer sc.mu.Unlock()
	return sc.trackChunks[trackURL]
}

// Clear removes all cached chunks for a track.
func (sc *Cache) Clear(trackURL string) {
	sc.mu.Lock()
	delete(sc.trackChunks, trackURL)
	sc.mu.Unlock()
}
