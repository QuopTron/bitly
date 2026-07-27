package streaming

import (
	"testing"
)

func TestStreamCacheAddGet(t *testing.T) {
	c := NewCache()

	c.Add("url1", Chunk{Data: []byte("chunk0"), Index: 0, Size: 6, IsLast: false})
	c.Add("url1", Chunk{Data: []byte("chunk1"), Index: 1, Size: 6, IsLast: true})

	data, ok := c.Get("url1", 0)
	if !ok || string(data) != "chunk0" {
		t.Errorf("expected chunk0, got %s (ok=%v)", string(data), ok)
	}

	data, ok = c.Get("url1", 1)
	if !ok || string(data) != "chunk1" {
		t.Errorf("expected chunk1, got %s (ok=%v)", string(data), ok)
	}
}

func TestStreamCacheGetMissing(t *testing.T) {
	c := NewCache()
	_, ok := c.Get("nonexistent", 0)
	if ok {
		t.Error("expected false for missing chunk")
	}
}

func TestStreamCacheChunkCount(t *testing.T) {
	c := NewCache()
	c.Add("url1", Chunk{Index: 0})
	c.Add("url1", Chunk{Index: 1})
	c.Add("url1", Chunk{Index: 2})

	count := c.ChunkCount("url1")
	if count != 3 {
		t.Errorf("expected 3 chunks, got %d", count)
	}
}

func TestStreamCacheChunkCountNewTrack(t *testing.T) {
	c := NewCache()
	count := c.ChunkCount("nonexistent")
	if count != 0 {
		t.Errorf("expected 0 for new track, got %d", count)
	}
}

func TestStreamCacheClear(t *testing.T) {
	c := NewCache()
	c.Add("url1", Chunk{Index: 0})
	c.Add("url1", Chunk{Index: 1})
	c.Clear("url1")

	count := c.ChunkCount("url1")
	if count != 0 {
		t.Errorf("expected 0 after clear, got %d", count)
	}

	// Note: Clear resets the chunk counter but doesn't remove cached data
	// from the underlying store (data expires via TTL).
	// Chunks remain accessible until TTL expiry.
	_, ok := c.Get("url1", 0)
	if !ok {
		t.Error("chunks may still exist in store after Clear (TTL-based eviction)")
	}
}

func TestStreamCacheMultipleTracks(t *testing.T) {
	c := NewCache()
	c.Add("url_a", Chunk{Data: []byte("a0"), Index: 0})
	c.Add("url_b", Chunk{Data: []byte("b0"), Index: 0})

	data, ok := c.Get("url_a", 0)
	if !ok || string(data) != "a0" {
		t.Errorf("expected a0, got %s", string(data))
	}

	data, ok = c.Get("url_b", 0)
	if !ok || string(data) != "b0" {
		t.Errorf("expected b0, got %s", string(data))
	}

	if c.ChunkCount("url_a") != 1 || c.ChunkCount("url_b") != 1 {
		t.Error("expected both tracks to have 1 chunk")
	}
}
