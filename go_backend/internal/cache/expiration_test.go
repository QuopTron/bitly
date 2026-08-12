package cache

import (
	"strconv"
	"sync"
	"testing"
	"time"
)

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
