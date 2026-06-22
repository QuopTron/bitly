package manager

import (
	"os"
	"path/filepath"
	"testing"
)

func TestGetExtension(t *testing.T) {
	m := NewManager()
	m.extensions["ext1"] = &Extension{ID: "ext1", Name: "Ext 1", Version: "1.0.0"}
	ext, err := m.GetExtension("ext1")
	if err != nil {
		t.Fatalf("GetExtension failed: %v", err)
	}
	if ext.ID != "ext1" {
		t.Errorf("got id %q, want %q", ext.ID, "ext1")
	}
	_, err = m.GetExtension("nonexistent")
	if err == nil {
		t.Fatal("expected error for nonexistent extension")
	}
}

func TestListExtensions(t *testing.T) {
	m := NewManager()
	if exts := m.ListExtensions(); len(exts) != 0 {
		t.Errorf("expected 0, got %d", len(exts))
	}
	m.extensions["a"] = &Extension{ID: "a"}
	m.extensions["b"] = &Extension{ID: "b"}
	exts := m.ListExtensions()
	if len(exts) != 2 {
		t.Fatalf("expected 2, got %d", len(exts))
	}
}

func TestUnloadExtension(t *testing.T) {
	m := NewManager()
	m.extensions["ext1"] = &Extension{ID: "ext1"}
	if err := m.UnloadExtension("ext1"); err != nil {
		t.Fatalf("UnloadExtension failed: %v", err)
	}
	if _, ok := m.extensions["ext1"]; ok {
		t.Error("extension was not removed")
	}
}

func TestRemoveExtension(t *testing.T) {
	dir := t.TempDir()
	sourceDir := filepath.Join(dir, "source")
	os.MkdirAll(sourceDir, 0755)
	m := NewManager()
	m.extensions["ext1"] = &Extension{ID: "ext1", SourceDir: sourceDir}
	if err := m.RemoveExtension("ext1"); err != nil {
		t.Fatalf("RemoveExtension failed: %v", err)
	}
	if _, ok := m.extensions["ext1"]; ok {
		t.Error("extension was not removed")
	}
	if _, err := os.Stat(sourceDir); !os.IsNotExist(err) {
		t.Error("source directory was not removed")
	}
}

func TestRemoveExtensionNotFound(t *testing.T) {
	m := NewManager()
	if err := m.RemoveExtension("nonexistent"); err == nil {
		t.Fatal("expected error for nonexistent extension")
	}
}

func TestSetExtensionEnabled(t *testing.T) {
	m := NewManager()
	m.extensions["ext1"] = &Extension{ID: "ext1", Error: "some error"}
	if err := m.SetExtensionEnabled("ext1", true); err != nil {
		t.Fatalf("SetExtensionEnabled(true) failed: %v", err)
	}
	if !m.extensions["ext1"].Enabled {
		t.Error("expected enabled = true")
	}
	if err := m.SetExtensionEnabled("ext1", false); err != nil {
		t.Fatalf("SetExtensionEnabled(false) failed: %v", err)
	}
	if m.extensions["ext1"].Enabled {
		t.Error("expected enabled = false")
	}
	if m.extensions["ext1"].Error != "" {
		t.Error("expected Error cleared when disabled")
	}
	if err := m.SetExtensionEnabled("nonexistent", true); err == nil {
		t.Fatal("expected error for nonexistent extension")
	}
}
