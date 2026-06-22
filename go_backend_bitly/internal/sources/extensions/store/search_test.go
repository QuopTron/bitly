package store

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manager"
)

func TestGetExtensionsWithStatus(t *testing.T) {
	s := &Store{
		manager: manager.NewManager(), registryURL: "https://example.com/reg.json",
		cache: &storeRegistry{Extensions: []storeExtension{
			{ID: "e1", Name: "Ext1", Version: "1.0", Description: "d1", Category: "utility", Downloads: 5, UpdatedAt: "2024-01-01"},
			{ID: "e2", Name: "Ext2", Version: "2.0", Description: "d2", Category: "metadata", Downloads: 10, UpdatedAt: "2024-02-01"},
		}},
		cacheTime: time.Now(), cacheTTL: 30 * time.Minute,
	}
	exts, err := s.GetExtensionsWithStatus(false)
	if err != nil { t.Fatal(err) }
	if len(exts) != 2 { t.Fatalf("len=%d want=2", len(exts)) }
	if exts[0].IsInstalled { t.Error("should not be installed") }
	if exts[0].HasUpdate { t.Error("should not have update") }
}

func TestSearchExtensionsEmpty(t *testing.T) {
	s := &Store{
		manager: manager.NewManager(), registryURL: "https://example.com/reg.json",
		cache: &storeRegistry{Extensions: []storeExtension{
			{ID: "e1", Name: "Ext1", Version: "1.0", Description: "first", Category: "utility", Downloads: 5, UpdatedAt: "2024-01-01"},
			{ID: "e2", Name: "Ext2", Version: "2.0", Description: "second", Category: "metadata", Downloads: 10, UpdatedAt: "2024-02-01"},
		}},
		cacheTime: time.Now(), cacheTTL: 30 * time.Minute,
	}
	exts, err := s.SearchExtensions("", "")
	if err != nil { t.Fatal(err) }
	if len(exts) != 2 { t.Fatalf("len=%d want=2", len(exts)) }
}

func TestSearchExtensionsByCategory(t *testing.T) {
	s := &Store{
		manager: manager.NewManager(), registryURL: "https://example.com/reg.json",
		cache: &storeRegistry{Extensions: []storeExtension{
			{ID: "e1", Name: "Ext1", Version: "1.0", Description: "first", Category: "utility", Downloads: 5, UpdatedAt: "2024-01-01"},
			{ID: "e2", Name: "Ext2", Version: "2.0", Description: "second", Category: "metadata", Downloads: 10, UpdatedAt: "2024-02-01"},
		}},
		cacheTime: time.Now(), cacheTTL: 30 * time.Minute,
	}
	exts, err := s.SearchExtensions("", "metadata")
	if err != nil { t.Fatal(err) }
	if len(exts) != 1 { t.Fatalf("len=%d want=1", len(exts)) }
	if exts[0].ID != "e2" { t.Errorf("id=%q want=e2", exts[0].ID) }
}

func TestSearchExtensionsByName(t *testing.T) {
	s := &Store{
		manager: manager.NewManager(), registryURL: "https://example.com/reg.json",
		cache: &storeRegistry{Extensions: []storeExtension{
			{ID: "e1", Name: "MyExtension", Version: "1.0", Description: "first", Category: "utility", Downloads: 5, UpdatedAt: "2024-01-01"},
			{ID: "e2", Name: "Other", Version: "2.0", Description: "second", Category: "metadata", Downloads: 10, UpdatedAt: "2024-02-01"},
		}},
		cacheTime: time.Now(), cacheTTL: 30 * time.Minute,
	}
	exts, err := s.SearchExtensions("extension", "")
	if err != nil { t.Fatal(err) }
	if len(exts) != 1 { t.Fatalf("len=%d want=1", len(exts)) }
	if exts[0].ID != "e1" { t.Errorf("id=%q want=e1", exts[0].ID) }
}

func TestSearchExtensionsByDescription(t *testing.T) {
	s := &Store{
		manager: manager.NewManager(), registryURL: "https://example.com/reg.json",
		cache: &storeRegistry{Extensions: []storeExtension{
			{ID: "e1", Name: "Ext1", Version: "1.0", Description: "Some metadata helper", Category: "utility", Downloads: 5, UpdatedAt: "2024-01-01"},
			{ID: "e2", Name: "Ext2", Version: "2.0", Description: "audio downloader", Category: "download", Downloads: 10, UpdatedAt: "2024-02-01"},
		}},
		cacheTime: time.Now(), cacheTTL: 30 * time.Minute,
	}
	exts, err := s.SearchExtensions("metadata", "")
	if err != nil { t.Fatal(err) }
	if len(exts) != 1 { t.Fatalf("len=%d want=1", len(exts)) }
	if exts[0].ID != "e1" { t.Errorf("id=%q want=e1", exts[0].ID) }
}

func TestSearchExtensionsByTag(t *testing.T) {
	s := &Store{
		manager: manager.NewManager(), registryURL: "https://example.com/reg.json",
		cache: &storeRegistry{Extensions: []storeExtension{
			{ID: "e1", Name: "Ext1", Version: "1.0", Description: "desc", Category: "utility", Tags: []string{"youtube", "video"}, Downloads: 5, UpdatedAt: "2024-01-01"},
			{ID: "e2", Name: "Ext2", Version: "2.0", Description: "desc", Category: "metadata", Downloads: 10, UpdatedAt: "2024-02-01"},
		}},
		cacheTime: time.Now(), cacheTTL: 30 * time.Minute,
	}
	exts, err := s.SearchExtensions("youtube", "")
	if err != nil { t.Fatal(err) }
	if len(exts) != 1 { t.Fatalf("len=%d want=1", len(exts)) }
	if exts[0].ID != "e1" { t.Errorf("id=%q want=e1", exts[0].ID) }
}
