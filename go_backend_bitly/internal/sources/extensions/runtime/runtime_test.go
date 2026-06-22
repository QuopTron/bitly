package runtime

import (
	"os"
	"path/filepath"
	"testing"
)

func writeTestJS(t *testing.T, content string) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "test.js")
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestNewExtensionRuntime(t *testing.T) {
	r := NewExtensionRuntime()
	if r == nil {
		t.Fatal("expected non-nil runtime")
	}
	if r.runtimes == nil {
		t.Fatal("expected runtimes map to be initialized")
	}
}

func TestIsLoaded(t *testing.T) {
	r := NewExtensionRuntime()
	if r.IsLoaded("nonexistent") {
		t.Error("expected false for unloaded")
	}
	jsPath := writeTestJS(t, `var extension = {};`)
	if err := r.LoadExtension("ext1", jsPath); err != nil {
		t.Fatal(err)
	}
	if !r.IsLoaded("ext1") {
		t.Error("expected true after load")
	}
}

func TestListLoaded(t *testing.T) {
	r := NewExtensionRuntime()
	if ids := r.ListLoaded(); len(ids) != 0 {
		t.Errorf("expected empty, got %v", ids)
	}
	jsPath := writeTestJS(t, `var extension = {};`)
	r.LoadExtension("a", jsPath)
	r.LoadExtension("b", jsPath)
	if ids := r.ListLoaded(); len(ids) != 2 {
		t.Errorf("expected 2, got %d", len(ids))
	}
}

func TestUnloadExtension(t *testing.T) {
	r := NewExtensionRuntime()
	r.UnloadExtension("nonexistent")
	jsPath := writeTestJS(t, `var extension = {};`)
	r.LoadExtension("ext1", jsPath)
	if !r.IsLoaded("ext1") {
		t.Fatal("expected loaded")
	}
	r.UnloadExtension("ext1")
	if r.IsLoaded("ext1") {
		t.Error("expected unloaded")
	}
}
