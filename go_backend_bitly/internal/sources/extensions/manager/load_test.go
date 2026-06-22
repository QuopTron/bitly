package manager

import (
	"archive/zip"
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func writeTestZip(t *testing.T, path, name, version, displayName string) {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	manifest := fmt.Sprintf(`{
		"name": "%s",
		"displayName": "%s",
		"version": "%s",
		"description": "test",
		"type": ["metadata_provider"],
		"permissions": {"network":[],"storage":false,"file":false}
	}`, name, displayName, version)
	f, _ := zw.Create("manifest.json")
	f.Write([]byte(manifest))
	f, _ = zw.Create("index.js")
	f.Write([]byte("// test"))
	zw.Close()
	os.WriteFile(path, buf.Bytes(), 0644)
}

func TestLoadExtensionInvalidPath(t *testing.T) {
	m := NewManager()
	_, err := m.LoadExtension("")
	if err == nil {
		t.Fatal("expected error for empty path")
	}
}

func TestLoadExtensionInvalidFormat(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.txt")
	os.WriteFile(path, []byte("not a zip"), 0644)
	m := NewManager()
	_, err := m.LoadExtension(path)
	if err == nil {
		t.Fatal("expected error for invalid format")
	}
}

func TestLoadExtensionCorruptedBitlyExt(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.bitly-ext")
	os.WriteFile(path, []byte("corrupted"), 0644)
	m := NewManager()
	_, err := m.LoadExtension(path)
	if err == nil {
		t.Fatal("expected error for corrupted file")
	}
}

func TestLoadExtensionSuccess(t *testing.T) {
	dir := t.TempDir()
	zipPath := filepath.Join(dir, "test.bitly-ext")
	writeTestZip(t, zipPath, "test-ext", "1.0.0", "Test Ext")
	m := NewManager()
	m.SetDirectories(filepath.Join(dir, "extensions"), filepath.Join(dir, "data"))
	ext, err := m.LoadExtension(zipPath)
	if err != nil {
		t.Fatalf("LoadExtension failed: %v", err)
	}
	if ext.ID != "test-ext" {
		t.Errorf("id = %q, want %q", ext.ID, "test-ext")
	}
	if ext.Enabled {
		t.Error("expected extension not enabled")
	}
}

func TestLoadExtensionAlreadyInstalled(t *testing.T) {
	dir := t.TempDir()
	zipPath := filepath.Join(dir, "test.bitly-ext")
	writeTestZip(t, zipPath, "test-ext", "1.0.0", "Test Ext")
	m := NewManager()
	m.SetDirectories(filepath.Join(dir, "extensions"), filepath.Join(dir, "data"))
	if _, err := m.LoadExtension(zipPath); err != nil {
		t.Fatalf("first load failed: %v", err)
	}
	_, err := m.LoadExtension(zipPath)
	if err == nil {
		t.Fatal("expected error for already installed")
	}
}

func TestLoadExtensionUpgrade(t *testing.T) {
	dir := t.TempDir()
	v1 := filepath.Join(dir, "v1.bitly-ext")
	writeTestZip(t, v1, "test-ext", "1.0.0", "Test Ext")
	v2 := filepath.Join(dir, "v2.bitly-ext")
	writeTestZip(t, v2, "test-ext", "2.0.0", "Test Ext")
	m := NewManager()
	m.SetDirectories(filepath.Join(dir, "extensions"), filepath.Join(dir, "data"))
	ext1, err := m.LoadExtension(v1)
	if err != nil {
		t.Fatalf("first load failed: %v", err)
	}
	ext2, err := m.LoadExtension(v2)
	if err != nil {
		t.Fatalf("upgrade failed: %v", err)
	}
	if ext2.Version != "2.0.0" {
		t.Errorf("version = %q, want %q", ext2.Version, "2.0.0")
	}
	if ext2.ID != ext1.ID {
		t.Error("expected same ID after upgrade")
	}
}

func TestLoadExtensionDowngrade(t *testing.T) {
	dir := t.TempDir()
	v1 := filepath.Join(dir, "v1.bitly-ext")
	writeTestZip(t, v1, "test-ext", "2.0.0", "Test Ext")
	v2 := filepath.Join(dir, "v2.bitly-ext")
	writeTestZip(t, v2, "test-ext", "1.0.0", "Test Ext")
	m := NewManager()
	m.SetDirectories(filepath.Join(dir, "extensions"), filepath.Join(dir, "data"))
	if _, err := m.LoadExtension(v1); err != nil {
		t.Fatalf("first load failed: %v", err)
	}
	_, err := m.LoadExtension(v2)
	if err == nil {
		t.Fatal("expected error for downgrade")
	}
}
