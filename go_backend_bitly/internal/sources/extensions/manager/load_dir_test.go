package manager

import (
	"os"
	"path/filepath"
	"testing"
)

var validManifest = `{
	"name": "test-ext",
	"displayName": "Test Extension",
	"version": "1.0.0",
	"description": "A test extension",
	"type": ["metadata_provider"],
	"permissions": {"network":[],"storage":false,"file":false}
}`

func writeExtDir(t *testing.T, parent, name string) string {
	t.Helper()
	dir := filepath.Join(parent, name)
	os.MkdirAll(dir, 0755)
	os.WriteFile(filepath.Join(dir, "manifest.json"), []byte(validManifest), 0644)
	os.WriteFile(filepath.Join(dir, "index.js"), []byte("// test"), 0644)
	return dir
}

func TestLoadExtensionFromDir(t *testing.T) {
	dir := t.TempDir()
	extDir := writeExtDir(t, dir, "test-ext")
	m := NewManager()
	m.SetDirectories(filepath.Join(dir, "extensions"), filepath.Join(dir, "data"))
	ext, err := m.LoadExtensionFromDir(extDir)
	if err != nil {
		t.Fatalf("LoadExtensionFromDir failed: %v", err)
	}
	if ext.ID != "test-ext" {
		t.Errorf("id = %q, want %q", ext.ID, "test-ext")
	}
	if ext.Enabled {
		t.Error("expected extension not enabled")
	}
}

func TestLoadExtensionFromDirMissingManifest(t *testing.T) {
	dir := t.TempDir()
	extDir := filepath.Join(dir, "bad-ext")
	os.MkdirAll(extDir, 0755)
	m := NewManager()
	m.SetDirectories(dir, dir)
	_, err := m.LoadExtensionFromDir(extDir)
	if err == nil {
		t.Fatal("expected error for missing manifest.json")
	}
}

func TestLoadExtensionFromDirMissingIndexJS(t *testing.T) {
	dir := t.TempDir()
	extDir := filepath.Join(dir, "bad-ext")
	os.MkdirAll(extDir, 0755)
	os.WriteFile(filepath.Join(extDir, "manifest.json"), []byte(validManifest), 0644)
	m := NewManager()
	m.SetDirectories(dir, dir)
	_, err := m.LoadExtensionFromDir(extDir)
	if err == nil {
		t.Fatal("expected error for missing index.js")
	}
}

func TestLoadExtensionFromDirAlreadyLoaded(t *testing.T) {
	dir := t.TempDir()
	extDir := writeExtDir(t, dir, "test-ext")
	m := NewManager()
	m.SetDirectories(filepath.Join(dir, "extensions"), filepath.Join(dir, "data"))
	ext1, err := m.LoadExtensionFromDir(extDir)
	if err != nil {
		t.Fatalf("first call failed: %v", err)
	}
	ext2, err := m.LoadExtensionFromDir(extDir)
	if err != nil {
		t.Fatalf("second call failed: %v", err)
	}
	if ext1 != ext2 {
		t.Error("expected same pointer for already loaded extension")
	}
}
