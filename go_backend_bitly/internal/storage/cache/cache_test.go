package cache

import (
	"sync"
	"testing"
	"time"
)

func TestNewCache(t *testing.T) {
	c := NewCache(100, time.Minute)
	if c == nil {
		t.Fatal("NewCache returned nil")
	}
	if c.Size() != 0 {
		t.Fatalf("expected size 0, got %d", c.Size())
	}
}

func TestSetAndGet(t *testing.T) {
	c := NewCache(100, time.Minute)
	c.Set("key1", "value1")

	v, ok := c.Get("key1")
	if !ok {
		t.Fatal("expected to find key1")
	}
	if v != "value1" {
		t.Fatalf("expected value1, got %v", v)
	}
}

func TestGetMissing(t *testing.T) {
	c := NewCache(100, time.Minute)
	_, ok := c.Get("nonexistent")
	if ok {
		t.Fatal("expected false for missing key")
	}
}

func TestGetExpired(t *testing.T) {
	c := NewCache(100, time.Nanosecond)
	c.Set("key1", "value1")

	time.Sleep(time.Nanosecond)

	_, ok := c.Get("key1")
	if ok {
		t.Fatal("expected false for expired key")
	}
}

func TestSetWithTTL(t *testing.T) {
	c := NewCache(100, time.Minute)
	c.SetWithTTL("key1", "value1", 50*time.Millisecond)

	time.Sleep(10 * time.Millisecond)
	v, ok := c.Get("key1")
	if !ok {
		t.Fatal("expected key1 to still be valid")
	}
	if v != "value1" {
		t.Fatalf("expected value1, got %v", v)
	}

	time.Sleep(50 * time.Millisecond)
	_, ok = c.Get("key1")
	if ok {
		t.Fatal("expected key1 to be expired")
	}
}

func TestMaxSizeEviction(t *testing.T) {
	c := NewCache(2, time.Minute)
	c.Set("a", "1")
	c.Set("b", "2")
	c.Set("c", "3")

	if c.Size() != 2 {
		t.Fatalf("expected size 2 after eviction, got %d", c.Size())
	}

	_, ok := c.Get("a")
	if ok {
		t.Fatal("expected a to be evicted (oldest)")
	}

	_, ok = c.Get("b")
	if !ok {
		t.Fatal("expected b to still be present")
	}
	_, ok = c.Get("c")
	if !ok {
		t.Fatal("expected c to still be present")
	}
}

func TestLRUOrdering(t *testing.T) {
	c := NewCache(2, time.Minute)
	c.Set("a", "1")
	c.Set("b", "2")

	c.Get("a")

	c.Set("c", "3")

	if c.Size() != 2 {
		t.Fatalf("expected size 2, got %d", c.Size())
	}

	_, ok := c.Get("a")
	if !ok {
		t.Fatal("expected a to be preserved (recently accessed)")
	}
	_, ok = c.Get("b")
	if ok {
		t.Fatal("expected b to be evicted (least recently used)")
	}
	_, ok = c.Get("c")
	if !ok {
		t.Fatal("expected c to be present")
	}
}

func TestDelete(t *testing.T) {
	c := NewCache(100, time.Minute)
	c.Set("key1", "value1")
	c.Delete("key1")

	if c.Size() != 0 {
		t.Fatalf("expected size 0 after delete, got %d", c.Size())
	}

	_, ok := c.Get("key1")
	if ok {
		t.Fatal("expected false after delete")
	}
}

func TestDeleteNonExistent(t *testing.T) {
	c := NewCache(100, time.Minute)
	c.Delete("nonexistent")
}

func TestClear(t *testing.T) {
	c := NewCache(100, time.Minute)
	c.Set("a", "1")
	c.Set("b", "2")
	c.Set("c", "3")

	c.Clear()

	if c.Size() != 0 {
		t.Fatalf("expected size 0 after clear, got %d", c.Size())
	}

	_, ok := c.Get("a")
	if ok {
		t.Fatal("expected false after clear")
	}
}

func TestOverwrite(t *testing.T) {
	c := NewCache(100, time.Minute)
	c.Set("key1", "value1")
	c.Set("key1", "value2")

	v, ok := c.Get("key1")
	if !ok {
		t.Fatal("expected to find key1")
	}
	if v != "value2" {
		t.Fatalf("expected value2, got %v", v)
	}
}

func TestConcurrentAccess(t *testing.T) {
	c := NewCache(1000, time.Minute)
	var wg sync.WaitGroup

	n := 50
	for i := range n {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			key := string(rune('a' + i))
			c.Set(key, i)
		}(i)
	}
	wg.Wait()

	if c.Size() != n {
		t.Fatalf("expected size %d, got %d", n, c.Size())
	}

	for i := range n {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			key := string(rune('a' + i))
			v, ok := c.Get(key)
			if !ok {
				t.Errorf("expected to find %s", key)
				return
			}
			if v != i {
				t.Errorf("expected %d for %s, got %v", i, key, v)
			}
		}(i)
	}
	wg.Wait()
}

func TestZeroMaxSize(t *testing.T) {
	c := NewCache(0, time.Minute)
	c.Set("a", "1")
	if c.Size() != 0 {
		t.Fatal("expected size 0 for zero-max cache")
	}
}

func TestSize(t *testing.T) {
	c := NewCache(10, time.Minute)
	if s := c.Size(); s != 0 {
		t.Fatalf("expected 0, got %d", s)
	}
	c.Set("a", "1")
	if s := c.Size(); s != 1 {
		t.Fatalf("expected 1, got %d", s)
	}
	c.Set("b", "2")
	if s := c.Size(); s != 2 {
		t.Fatalf("expected 2, got %d", s)
	}
	c.Delete("a")
	if s := c.Size(); s != 1 {
		t.Fatalf("expected 1, got %d", s)
	}
}
