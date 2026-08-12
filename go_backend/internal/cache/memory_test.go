package cache

import (
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
