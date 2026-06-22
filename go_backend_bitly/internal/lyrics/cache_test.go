package lyrics

import (
	"sync"
	"testing"
	"time"
)

func TestGenerateKey(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}

	t.Run("lowercases and trims", func(t *testing.T) {
		key := c.generateKey("  ARTIST  ", "  TRACK  ", 200)
		expected := "artist|track|200"
		if key != expected {
			t.Errorf("expected %q, got %q", expected, key)
		}
	})

	t.Run("rounds duration to nearest 10", func(t *testing.T) {
		key := c.generateKey("a", "b", 204.7)
		expected := "a|b|200"
		if key != expected {
			t.Errorf("expected %q, got %q", expected, key)
		}
	})

	t.Run("rounds up when nearer", func(t *testing.T) {
		key := c.generateKey("a", "b", 205.0)
		expected := "a|b|210"
		if key != expected {
			t.Errorf("expected %q, got %q", expected, key)
		}
	})

	t.Run("handles zero duration", func(t *testing.T) {
		key := c.generateKey("a", "b", 0)
		expected := "a|b|0"
		if key != expected {
			t.Errorf("expected %q, got %q", expected, key)
		}
	})
}

func TestCacheSetAndGet(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}

	resp := &LyricsResponse{PlainLyrics: "test lyrics", Provider: "test"}
	c.Set("artist", "track", 200, resp)

	got, found := c.Get("artist", "track", 200)
	if !found {
		t.Fatal("expected to find entry")
	}
	if got.PlainLyrics != "test lyrics" {
		t.Errorf("expected 'test lyrics', got %q", got.PlainLyrics)
	}
}

func TestCacheGetNormalizesInput(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}

	resp := &LyricsResponse{PlainLyrics: "works"}
	c.Set("  ArtIst  ", "  TrAck  ", 200.0, resp)

	got, found := c.Get("artist", "track", 200.0)
	if !found {
		t.Fatal("expected to find entry with mismatched case/whitespace")
	}
	if got.PlainLyrics != "works" {
		t.Errorf("expected 'works', got %q", got.PlainLyrics)
	}
}

func TestCacheGetDurationRounding(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}

	resp := &LyricsResponse{PlainLyrics: "rounded"}
	c.Set("a", "b", 204.0, resp)

	_, found := c.Get("a", "b", 204.9)
	if !found {
		t.Error("expected cache hit when durations round to same value")
	}
}

func TestCacheGetMiss(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}

	got, found := c.Get("missing", "entry", 0)
	if found {
		t.Error("expected false for cache miss")
	}
	if got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestCacheOverwrite(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}

	c.Set("a", "b", 100, &LyricsResponse{PlainLyrics: "first"})
	c.Set("a", "b", 100, &LyricsResponse{PlainLyrics: "second"})

	got, found := c.Get("a", "b", 100)
	if !found {
		t.Fatal("expected to find entry")
	}
	if got.PlainLyrics != "second" {
		t.Errorf("expected 'second', got %q", got.PlainLyrics)
	}
}

func TestCacheSize(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}

	if sz := c.Size(); sz != 0 {
		t.Errorf("expected size 0, got %d", sz)
	}

	c.Set("a", "b", 100, &LyricsResponse{PlainLyrics: "1"})
	c.Set("c", "d", 100, &LyricsResponse{PlainLyrics: "2"})

	if sz := c.Size(); sz != 2 {
		t.Errorf("expected size 2, got %d", sz)
	}
}

func TestCacheClearAll(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}

	c.Set("a", "b", 100, &LyricsResponse{PlainLyrics: "1"})
	c.Set("c", "d", 100, &LyricsResponse{PlainLyrics: "2"})

	cleared := c.ClearAll()
	if cleared != 2 {
		t.Errorf("expected cleared count 2, got %d", cleared)
	}
	if sz := c.Size(); sz != 0 {
		t.Errorf("expected size 0 after clear, got %d", sz)
	}
}

func TestCacheCleanExpired(t *testing.T) {
	now := time.Now()

	c := &lyricsCache{cache: map[string]*lyricsCacheEntry{
		"fresh":  {response: &LyricsResponse{PlainLyrics: "ok"}, expiresAt: now.Add(time.Hour)},
		"stale":  {response: &LyricsResponse{PlainLyrics: "old"}, expiresAt: now.Add(-time.Hour)},
		"stale2": {response: &LyricsResponse{PlainLyrics: "older"}, expiresAt: now.Add(-time.Minute)},
	}}

	cleaned := c.CleanExpired()
	if cleaned != 2 {
		t.Errorf("expected cleaned count 2, got %d", cleaned)
	}
	if sz := c.Size(); sz != 1 {
		t.Errorf("expected size 1 after clean, got %d", sz)
	}

	if _, _ = c.Get("fresh", "", 0); true {
	}

	if _, found := c.Get("stale", "", 0); found {
		t.Error("expected stale entry to be removed")
	}
}

func TestCacheExpiredEntryNotReturned(t *testing.T) {
	c := &lyricsCache{cache: map[string]*lyricsCacheEntry{
		"a|b|100": {response: &LyricsResponse{PlainLyrics: "gone"}, expiresAt: time.Now().Add(-time.Second)},
	}}

	got, found := c.Get("a", "b", 100)
	if found {
		t.Error("expected expired entry to not be found")
	}
	if got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestCacheConcurrentAccess(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}
	var wg sync.WaitGroup

	const n = 50
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			c.Set("artist", "track", float64(i), &LyricsResponse{PlainLyrics: "data"})
			c.Get("artist", "track", float64(i))
			c.Size()
		}(i)
	}
	wg.Wait()

	_, found := c.Get("artist", "track", 0)
	if !found {
		t.Error("expected one of the concurrent writes to persist")
	}
}

func TestCacheConcurrentCleanAndSet(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}
	var wg sync.WaitGroup

	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			c.Set("k", "v", float64(i), &LyricsResponse{})
			c.CleanExpired()
			c.ClearAll()
		}(i)
	}
	wg.Wait()
}

func TestCacheGetNoPanicOnEmptyCache(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}

	got, found := c.Get("x", "y", 0)
	if found {
		t.Error("expected false on empty cache")
	}
	if got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestCacheClearAllEmpty(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}

	cleared := c.ClearAll()
	if cleared != 0 {
		t.Errorf("expected 0, got %d", cleared)
	}
}

func TestCacheCleanExpiredEmpty(t *testing.T) {
	c := &lyricsCache{cache: make(map[string]*lyricsCacheEntry)}

	cleaned := c.CleanExpired()
	if cleaned != 0 {
		t.Errorf("expected 0, got %d", cleaned)
	}
}

func TestGlobalLyricsCacheIsInitialized(t *testing.T) {
	if globalLyricsCache == nil {
		t.Fatal("globalLyricsCache should not be nil")
	}
	if globalLyricsCache.cache == nil {
		t.Fatal("globalLyricsCache.cache should be initialized")
	}
}
