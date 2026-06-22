package availability

import (
	"sync"
	"testing"
	"time"
)

func TestNewCache(t *testing.T) {
	c := NewCache(time.Minute, 100)
	if c == nil {
		t.Fatal("NewCache returned nil")
	}
	if c.ttl != time.Minute {
		t.Errorf("ttl = %v, want %v", c.ttl, time.Minute)
	}
	if c.maxSize != 100 {
		t.Errorf("maxSize = %d, want 100", c.maxSize)
	}
	if c.entries == nil {
		t.Error("entries map is nil")
	}
}

func TestCacheSetGet(t *testing.T) {
	c := NewCache(time.Minute, 100)
	key := "test-key"
	result := []AvailabilityResult{
		{Provider: "deezer", TrackID: "123", Available: true, Quality: "lossless"},
		{Provider: "tidal", TrackID: "456", Available: false},
	}

	c.Set(key, result)

	got, ok := c.Get(key)
	if !ok {
		t.Fatal("Get returned false for existing key")
	}
	if len(got) != 2 {
		t.Fatalf("got %d results, want 2", len(got))
	}
	if got[0].Provider != "deezer" || got[0].TrackID != "123" {
		t.Errorf("got[0] = %+v, want {Provider:deezer TrackID:123}", got[0])
	}
	if got[1].Provider != "tidal" || got[1].TrackID != "456" {
		t.Errorf("got[1] = %+v, want {Provider:tidal TrackID:456}", got[1])
	}
}

func TestCacheGetMissing(t *testing.T) {
	c := NewCache(time.Minute, 100)
	_, ok := c.Get("nonexistent")
	if ok {
		t.Error("Get returned true for missing key")
	}
}

func TestCacheGetAfterClear(t *testing.T) {
	c := NewCache(time.Minute, 100)
	c.Set("key", []AvailabilityResult{{Provider: "test"}})
	c.Clear()

	_, ok := c.Get("key")
	if ok {
		t.Error("Get returned true after Clear")
	}
}

func TestCacheEviction(t *testing.T) {
	c := NewCache(time.Minute, 1)
	c.Set("a", []AvailabilityResult{{Provider: "a"}})
	c.Set("b", []AvailabilityResult{{Provider: "b"}})

	_, ok := c.Get("a")
	if ok {
		t.Error("Get returned true for evicted key 'a'")
	}
	_, ok = c.Get("b")
	if !ok {
		t.Error("Get returned false for existing key 'b'")
	}
}

func TestCacheEvictionPreservesSizeLimit(t *testing.T) {
	c := NewCache(time.Minute, 3)
	for i := 0; i < 10; i++ {
		key := string(rune('a' + i))
		c.Set(key, []AvailabilityResult{{Provider: key}})
	}
	if len(c.entries) > 3 {
		t.Errorf("cache has %d entries, want ≤3", len(c.entries))
	}
}

func TestCacheExpiredEntry(t *testing.T) {
	c := NewCache(1*time.Millisecond, 100)
	c.Set("key", []AvailabilityResult{{Provider: "test"}})

	time.Sleep(5 * time.Millisecond)

	_, ok := c.Get("key")
	if ok {
		t.Error("Get returned true for expired key")
	}
}

func TestCacheConcurrentAccess(t *testing.T) {
	c := NewCache(time.Minute, 1000)
	var wg sync.WaitGroup

	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			key := string(rune('a' + n))
			c.Set(key, []AvailabilityResult{{Provider: key}})
			c.Get(key)
		}(i)
	}

	wg.Wait()

	if len(c.entries) != 50 {
		t.Errorf("expected 50 entries, got %d", len(c.entries))
	}
}

func TestCacheOverwrite(t *testing.T) {
	c := NewCache(time.Minute, 100)
	c.Set("key", []AvailabilityResult{{Provider: "old"}})
	c.Set("key", []AvailabilityResult{{Provider: "new"}})

	got, ok := c.Get("key")
	if !ok {
		t.Fatal("Get returned false after overwrite")
	}
	if len(got) != 1 || got[0].Provider != "new" {
		t.Errorf("got %+v, want [{Provider:new}]", got)
	}
}
