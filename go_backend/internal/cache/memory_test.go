package cache

import (
	"strconv"
	"sync"
	"testing"
	"time"
)

func TestCacheSetGet(t *testing.T) {
	c := New[string](time.Minute, 0)
	c.Set("key1", "value1")
	c.Set("key2", "value2")

	v, ok := c.Get("key1")
	if !ok || v != "value1" {
		t.Errorf("expected value1, got %v (ok=%v)", v, ok)
	}

	v, ok = c.Get("key2")
	if !ok || v != "value2" {
		t.Errorf("expected value2, got %v (ok=%v)", v, ok)
	}
}

func TestCacheGetMissing(t *testing.T) {
	c := New[string](time.Minute, 0)
	_, ok := c.Get("nonexistent")
	if ok {
		t.Error("expected false for missing key")
	}
}

func TestCacheDelete(t *testing.T) {
	c := New[string](time.Minute, 0)
	c.Set("key", "value")
	c.Delete("key")

	_, ok := c.Get("key")
	if ok {
		t.Error("expected false after delete")
	}
}

func TestCacheClear(t *testing.T) {
	c := New[string](time.Minute, 0)
	c.Set("a", "1")
	c.Set("b", "2")
	c.Clear()

	if c.Len() != 0 {
		t.Errorf("expected 0 after clear, got %d", c.Len())
	}
}

func TestCacheLen(t *testing.T) {
	c := New[string](time.Minute, 0)
	if c.Len() != 0 {
		t.Errorf("expected empty cache, got %d", c.Len())
	}

	c.Set("a", "1")
	if c.Len() != 1 {
		t.Errorf("expected 1, got %d", c.Len())
	}

	c.Set("b", "2")
	if c.Len() != 2 {
		t.Errorf("expected 2, got %d", c.Len())
	}
}

func TestCacheExpiration(t *testing.T) {
	c := New[string](50*time.Millisecond, 0)
	c.Set("key", "value")

	// Should exist immediately
	_, ok := c.Get("key")
	if !ok {
		t.Error("expected key to exist before expiration")
	}

	// Wait for expiration
	time.Sleep(100 * time.Millisecond)

	_, ok = c.Get("key")
	if ok {
		t.Error("expected key to be expired")
	}
}

func TestCacheCustomTTL(t *testing.T) {
	c := New[string](time.Minute, 0)

	// Set with a very short TTL override
	c.Set("short", "value", 20*time.Millisecond)

	// Set with default TTL (long)
	c.Set("long", "value")

	time.Sleep(30 * time.Millisecond)

	_, shortOK := c.Get("short")
	_, longOK := c.Get("long")

	if shortOK {
		t.Error("expected short TTL key to expire")
	}
	if !longOK {
		t.Error("expected long TTL key to still exist")
	}
}

func TestCacheHas(t *testing.T) {
	c := New[string](time.Minute, 0)
	c.Set("key", "value")

	if !c.Has("key") {
		t.Error("Has should return true for existing key")
	}
	if c.Has("nonexistent") {
		t.Error("Has should return false for missing key")
	}
}

func TestCacheHasExpired(t *testing.T) {
	c := New[string](20*time.Millisecond, 0)
	c.Set("key", "value")

	time.Sleep(30 * time.Millisecond)
	if c.Has("key") {
		t.Error("Has should return false for expired key")
	}
}

func TestCacheCleanup(t *testing.T) {
	c := New[string](20*time.Millisecond, 50*time.Millisecond)
	c.Set("key", "value")

	// Wait for expiration + cleanup
	time.Sleep(100 * time.Millisecond)

	if c.Len() != 0 {
		t.Errorf("expected cleanup to remove expired entries, got %d items", c.Len())
	}

	c.Close()
}

func TestCacheClose(t *testing.T) {
	c := New[string](time.Minute, time.Second)
	c.Set("key", "value")
	c.Close()

	// After close, cleanup goroutine stops. Value should still be accessible.
	v, ok := c.Get("key")
	if !ok || v != "value" {
		t.Error("values should still be accessible after close")
	}
}

func TestCacheConcurrent(t *testing.T) {
	c := New[int](time.Minute, 0)
	var wg sync.WaitGroup

	// Concurrent writes
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			c.Set(strconv.Itoa(n), n)
		}(i)
	}
	wg.Wait()

	if c.Len() != 100 {
		t.Errorf("expected 100 items, got %d", c.Len())
	}

	// Concurrent reads
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			v, ok := c.Get(strconv.Itoa(n))
			if !ok || v != n {
				t.Errorf("expected %d, got %d (ok=%v)", n, v, ok)
			}
		}(i)
	}
	wg.Wait()
}
