package store

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manager"
)

func TestFetchRegistryNoURL(t *testing.T) {
	s := &Store{manager: manager.NewManager()}
	_, err := s.FetchRegistry(false)
	if err == nil { t.Fatal("expected error") }
}

func TestFetchRegistryFromCache(t *testing.T) {
	reg := &storeRegistry{
		Version: 1,
		Extensions: []storeExtension{
			{ID: "e1", Name: "E1", Version: "1.0", Category: "utility", Downloads: 0, UpdatedAt: "2024-01-01"},
		},
	}
	s := &Store{
		manager: manager.NewManager(), registryURL: "https://example.com/reg.json",
		cache: reg, cacheTime: time.Now(), cacheTTL: 30 * time.Minute,
	}
	got, err := s.FetchRegistry(false)
	if err != nil { t.Fatal(err) }
	if got != reg { t.Error("should return cached registry") }
}

func TestFetchRegistryForceRefreshFallsBack(t *testing.T) {
	reg := &storeRegistry{
		Version: 2,
		Extensions: []storeExtension{
			{ID: "e2", Name: "E2", Version: "2.0", Category: "metadata", Downloads: 0, UpdatedAt: "2024-01-01"},
		},
	}
	s := &Store{
		manager: manager.NewManager(), registryURL: "https://example.com/reg.json",
		cache: reg, cacheTime: time.Now(), cacheTTL: 30 * time.Minute,
	}
	got, err := s.FetchRegistry(true)
	if err != nil { t.Fatal(err) }
	if got != reg { t.Error("should fall back to cache on HTTP error") }
}

func TestClearCache(t *testing.T) {
	s := &Store{
		manager: manager.NewManager(), cache: &storeRegistry{},
		cacheTime: time.Now(), cacheDir: t.TempDir(),
	}
	s.ClearCache()
	if s.cache != nil { t.Error("cache should be nil") }
	if !s.cacheTime.IsZero() { t.Error("cacheTime should be zero") }
}

func TestDownloadExtensionNotFound(t *testing.T) {
	s := &Store{
		manager: manager.NewManager(), registryURL: "https://example.com/reg.json",
		cache: &storeRegistry{Extensions: []storeExtension{
			{ID: "existing", Name: "Existing", Version: "1.0", Category: "utility", Downloads: 0, UpdatedAt: "2024-01-01"},
		}},
		cacheTime: time.Now(), cacheTTL: 30 * time.Minute,
	}
	err := s.DownloadExtension("nonexistent", t.TempDir()+"/ext.bitly-ext")
	if err == nil { t.Fatal("expected error") }
}
