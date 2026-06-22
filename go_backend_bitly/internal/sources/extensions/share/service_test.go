package share

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manager"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/runtime"
)

func newTestService(t *testing.T) *Service {
	t.Helper()
	dir := t.TempDir()
	extDir := filepath.Join(dir, "ext")
	dataDir := filepath.Join(dir, "data")
	os.MkdirAll(extDir, 0755)
	os.MkdirAll(dataDir, 0755)
	manifest := `{
		"name": "test-ext",
		"displayName": "Test Ext",
		"version": "1.0.0",
		"description": "test",
		"type": ["metadata_provider"],
		"permissions": {"network":[],"storage":false,"file":false},
		"capabilities": {
			"shareUrlTemplates": {
				"album": "https://ex.com/album/{id}",
				"artist": "https://ex.com/artist/{id}"
			}
		}
	}`
	os.WriteFile(filepath.Join(extDir, "manifest.json"), []byte(manifest), 0644)
	os.WriteFile(filepath.Join(extDir, "index.js"), []byte("//test"), 0644)
	mgr := manager.NewManager()
	mgr.SetDirectories(extDir, dataDir)
	mgr.LoadExtensionFromDir(extDir)
	rt := runtime.NewExtensionRuntime()
	return NewService(mgr, rt)
}

func TestNewService(t *testing.T) {
	mgr := manager.NewManager()
	rt := runtime.NewExtensionRuntime()
	svc := NewService(mgr, rt)
	if svc == nil {
		t.Fatal("NewService returned nil")
	}
	if svc.cache == nil {
		t.Error("cache map not initialized")
	}
}

func TestBuildCacheKey(t *testing.T) {
	svc := newTestService(t)
	key := svc.buildCacheKey("Album", "Artist", "album", "src1", []string{"ext1", "ext2"})
	if key == "" {
		t.Error("expected non-empty key")
	}
}

func TestCacheGetSet(t *testing.T) {
	svc := newTestService(t)
	if got := svc.cacheGet("missing"); got != "" {
		t.Errorf("expected empty for missing key, got %q", got)
	}
	if got := svc.cacheGet(""); got != "" {
		t.Errorf("expected empty for empty key, got %q", got)
	}
	svc.cacheSet("", "value")
	svc.cacheSet("key", "")
	if len(svc.cache) != 0 {
		t.Error("expected cache to stay empty for invalid sets")
	}
	svc.cacheSet("k1", "v1")
	if got := svc.cacheGet("k1"); got != "v1" {
		t.Errorf("expected v1, got %q", got)
	}
	svc.cacheSet("k1", "v2")
	if got := svc.cacheGet("k1"); got != "v2" {
		t.Errorf("expected v2 after overwrite, got %q", got)
	}
}
