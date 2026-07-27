package cache

import (
	"testing"
)

func TestLRUSetGet(t *testing.T) {
	lru := NewLRU[string](3)
	lru.Set("a", "1")
	lru.Set("b", "2")
	lru.Set("c", "3")

	v, ok := lru.Get("a")
	if !ok || v != "1" {
		t.Errorf("expected 1, got %v", v)
	}
}

func TestLRUEviction(t *testing.T) {
	lru := NewLRU[string](3)
	lru.Set("a", "1")
	lru.Set("b", "2")
	lru.Set("c", "3")
	lru.Set("d", "4") // should evict "a"

	_, ok := lru.Get("a")
	if ok {
		t.Error("expected 'a' to be evicted")
	}

	v, ok := lru.Get("d")
	if !ok || v != "4" {
		t.Errorf("expected 4, got %v", v)
	}
}

func TestLRUAccessOrder(t *testing.T) {
	lru := NewLRU[string](3)
	lru.Set("a", "1")
	lru.Set("b", "2")
	lru.Set("c", "3")

	// Access "a" to make it most recent
	lru.Get("a")
	lru.Set("d", "4") // should evict "b" (least recently used)

	_, bOK := lru.Get("b")
	_, aOK := lru.Get("a")

	if bOK {
		t.Error("expected 'b' to be evicted (was LRU)")
	}
	if !aOK {
		t.Error("expected 'a' to exist (was accessed)")
	}
}

func TestLRUUpdateValue(t *testing.T) {
	lru := NewLRU[string](3)
	lru.Set("a", "1")
	lru.Set("a", "2") // update

	v, ok := lru.Get("a")
	if !ok || v != "2" {
		t.Errorf("expected 2, got %v", v)
	}
}

func TestLRULen(t *testing.T) {
	lru := NewLRU[string](5)
	if lru.Len() != 0 {
		t.Errorf("expected 0, got %d", lru.Len())
	}

	lru.Set("a", "1")
	if lru.Len() != 1 {
		t.Errorf("expected 1, got %d", lru.Len())
	}
}

func TestLRUClear(t *testing.T) {
	lru := NewLRU[string](3)
	lru.Set("a", "1")
	lru.Set("b", "2")
	lru.Clear()

	if lru.Len() != 0 {
		t.Errorf("expected 0 after clear, got %d", lru.Len())
	}

	_, ok := lru.Get("a")
	if ok {
		t.Error("expected no value after clear")
	}
}

func TestLRUZeroCapacity(t *testing.T) {
	lru := NewLRU[string](0)
	lru.Set("a", "1")
	if lru.Len() > 1 {
		t.Errorf("expected at most 1 for zero-capacity LRU, got %d", lru.Len())
	}
}

func TestLRUDelete(t *testing.T) {
	lru := NewLRU[string](3)
	lru.Set("a", "1")
	lru.Set("b", "2")

	lru.Delete("a")
	_, ok := lru.Get("a")
	if ok {
		t.Error("expected no value after delete")
	}
	if lru.Len() != 1 {
		t.Errorf("expected 1 after delete, got %d", lru.Len())
	}
}

func TestLRUIntValues(t *testing.T) {
	lru := NewLRU[int](3)
	lru.Set("a", 100)
	lru.Set("b", 200)

	v, ok := lru.Get("a")
	if !ok || v != 100 {
		t.Errorf("expected 100, got %d", v)
	}
}
