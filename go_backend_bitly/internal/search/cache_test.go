package search

import (
	"testing"
	"time"
)

func TestCacheGetNonExistent(t *testing.T) {
	c := NewCache(time.Minute, 10)
	got, ok := c.Get("nonexistent")
	if ok {
		t.Errorf("Get for nonexistent key returned ok=true, got=%v", got)
	}
	if got != nil {
		t.Errorf("Get for nonexistent key returned %v, want nil", got)
	}
}

func TestCacheSetGet(t *testing.T) {
	c := NewCache(time.Minute, 10)
	key := "test|track"
	result := &SearchResult{Query: "test", Type: "track"}
	c.Set(key, result)

	got, ok := c.Get(key)
	if !ok {
		t.Fatal("expected ok=true after Set")
	}
	if got.Query != "test" || got.Type != "track" {
		t.Errorf("got Query=%q Type=%q, want Query=test Type=track", got.Query, got.Type)
	}
}

func TestCacheOverwrite(t *testing.T) {
	c := NewCache(time.Minute, 10)
	key := "same|track"
	c.Set(key, &SearchResult{Query: "first"})
	c.Set(key, &SearchResult{Query: "second"})

	got, ok := c.Get(key)
	if !ok {
		t.Fatal("expected ok=true after overwrite")
	}
	if got.Query != "second" {
		t.Errorf("got Query=%q, want second", got.Query)
	}
}

func TestCacheMaxSizeEviction(t *testing.T) {
	c := NewCache(time.Minute, 2)
	c.Set("a", &SearchResult{Query: "a"})
	c.Set("b", &SearchResult{Query: "b"})
	c.Set("c", &SearchResult{Query: "c"})

	if _, ok := c.Get("a"); ok {
		t.Log("note: first entry may have been evicted")
	}
	_, bOk := c.Get("b")
	_, cOk := c.Get("c")
	if !bOk && !cOk {
		t.Error("expected at least one of b or c to remain after eviction")
	}
	if len(c.entries) > 2 {
		t.Errorf("expected at most 2 entries after eviction, got %d", len(c.entries))
	}
}

func TestCacheConcurrency(t *testing.T) {
	c := NewCache(time.Minute, 100)
	done := make(chan bool, 10)
	for i := 0; i < 10; i++ {
		go func(n int) {
			key := string(rune('a' + n))
			c.Set(key, &SearchResult{Query: key})
			c.Get(key)
			done <- true
		}(i)
	}
	for i := 0; i < 10; i++ {
		<-done
	}
}

func TestCacheTTLExpiry(t *testing.T) {
	c := NewCache(5*time.Millisecond, 10)
	c.Set("soon", &SearchResult{Query: "gone"})

	if _, ok := c.Get("soon"); !ok {
		t.Fatal("expected entry to be available immediately")
	}

	time.Sleep(20 * time.Millisecond)

	got, ok := c.Get("soon")
	if ok {
		t.Errorf("expected expired entry to be evicted, got=%v", got)
	}
}

func TestCacheSizeStableAfterEviction(t *testing.T) {
	c := NewCache(time.Minute, 3)
	for i := 0; i < 10; i++ {
		c.Set(string(rune('a'+i)), &SearchResult{Query: "q"})
	}
	if len(c.entries) > 3 {
		t.Errorf("entries grew beyond maxSize: %d", len(c.entries))
	}
}
