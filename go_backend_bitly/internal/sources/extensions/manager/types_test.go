package manager

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNewManager(t *testing.T) {
	m := NewManager()
	if m == nil {
		t.Fatal("expected non-nil manager")
	}
	if m.extensions == nil {
		t.Fatal("expected initialized extensions map")
	}
}

func TestSetDirectories(t *testing.T) {
	dir := t.TempDir()
	extDir := filepath.Join(dir, "extensions")
	dataDir := filepath.Join(dir, "data")

	m := NewManager()
	if err := m.SetDirectories(extDir, dataDir); err != nil {
		t.Fatalf("SetDirectories failed: %v", err)
	}
	if _, err := os.Stat(extDir); os.IsNotExist(err) {
		t.Error("extensions directory was not created")
	}
	if _, err := os.Stat(dataDir); os.IsNotExist(err) {
		t.Error("data directory was not created")
	}
}

func TestExtensionStruct(t *testing.T) {
	ext := &Extension{
		ID:      "test-id",
		Name:    "Test",
		Version: "1.0.0",
		Enabled: true,
		Type:    "metadata_provider",
	}
	if ext.ID != "test-id" {
		t.Errorf("id = %q, want %q", ext.ID, "test-id")
	}
	if ext.Error != "" {
		t.Errorf("expected empty error, got %q", ext.Error)
	}
}
