package extensions

import (
	"os"
	"testing"
)

func TestStorageNew(t *testing.T) {
	dir, _ := os.MkdirTemp("", "ext-test-*")
	defer os.RemoveAll(dir)

	s := NewStorage(dir, "test-ext")
	if s == nil {
		t.Fatal("expected non-nil Storage")
	}
	if s.filePath == "" {
		t.Error("expected non-empty filePath")
	}
}

func TestStorageFilePathFormat(t *testing.T) {
	dir, _ := os.MkdirTemp("", "ext-test-*")
	defer os.RemoveAll(dir)

	s := NewStorage(dir, "my-ext")
	if s.filePath == "" {
		t.Error("expected non-empty filePath")
	}
	if len(s.filePath) <= len(dir) {
		t.Errorf("filePath should be longer than dir, got %s", s.filePath)
	}
}

func TestStorageInternalDataMap(t *testing.T) {
	dir, _ := os.MkdirTemp("", "ext-test-*")
	defer os.RemoveAll(dir)

	s := NewStorage(dir, "test-ext")
	if s.data == nil {
		t.Error("expected non-nil data map")
	}
	if len(s.data) != 0 {
		t.Errorf("expected empty data map, got %d entries", len(s.data))
	}
}

func TestStorageSaveAndLoad(t *testing.T) {
	dir, _ := os.MkdirTemp("", "ext-test-*")
	defer os.RemoveAll(dir)

	// Manually write data and save
	s1 := NewStorage(dir, "persist")
	s1.mu.Lock()
	s1.data["key1"] = "value1"
	s1.data["key2"] = "value2"
	s1.mu.Unlock()
	s1.save()

	// Create new instance and load
	s2 := NewStorage(dir, "persist")
	s2.load()

	s2.mu.Lock()
	v1, ok1 := s2.data["key1"]
	v2, ok2 := s2.data["key2"]
	s2.mu.Unlock()

	if !ok1 || v1 != "value1" {
		t.Errorf("expected value1 after load, got %s (ok=%v)", v1, ok1)
	}
	if !ok2 || v2 != "value2" {
		t.Errorf("expected value2 after load, got %s (ok=%v)", v2, ok2)
	}
}

func TestStorageIsolation(t *testing.T) {
	dir, _ := os.MkdirTemp("", "ext-test-*")
	defer os.RemoveAll(dir)

	s1 := NewStorage(dir, "ext-a")
	s2 := NewStorage(dir, "ext-b")

	s1.mu.Lock()
	s1.data["key"] = "a-value"
	s1.mu.Unlock()
	s1.save()

	s2.mu.Lock()
	s2.data["key"] = "b-value"
	s2.mu.Unlock()
	s2.save()

	// Verify isolation
	s1loaded := NewStorage(dir, "ext-a")
	s1loaded.load()
	s1loaded.mu.Lock()
	v := s1loaded.data["key"]
	s1loaded.mu.Unlock()
	if v != "a-value" {
		t.Errorf("expected a-value from ext-a store, got %s", v)
	}

	s2loaded := NewStorage(dir, "ext-b")
	s2loaded.load()
	s2loaded.mu.Lock()
	v = s2loaded.data["key"]
	s2loaded.mu.Unlock()
	if v != "b-value" {
		t.Errorf("expected b-value from ext-b store, got %s", v)
	}
}

func TestStorageEmptyDirDoesNotPanic(t *testing.T) {
	s := NewStorage("", "test")
	if s == nil {
		t.Fatal("expected non-nil Storage even with empty dir")
	}
	// save with empty dir should not panic
	s.save()
	// load with empty dir should not panic
	s.load()
}

