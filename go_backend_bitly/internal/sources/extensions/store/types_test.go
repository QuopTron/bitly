package store

import (
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manager"
)

func TestStoreExtensionGetDisplayName(t *testing.T) {
	tests := []struct{ ext storeExtension; want string }{
		{storeExtension{Name: "n", DisplayName: "dn"}, "dn"},
		{storeExtension{Name: "n", DisplayNameAlt: "dna"}, "dna"},
		{storeExtension{Name: "n"}, "n"},
	}
	for i, tt := range tests {
		if got := tt.ext.getDisplayName(); got != tt.want {
			t.Errorf("[%d] getDisplayName() = %q, want %q", i, got, tt.want)
		}
	}
}

func TestStoreExtensionGetDownloadURL(t *testing.T) {
	tests := []struct{ ext storeExtension; want string }{
		{storeExtension{DownloadURL: "a"}, "a"},
		{storeExtension{DownloadURLAlt: "b"}, "b"},
		{storeExtension{}, ""},
	}
	for i, tt := range tests {
		if got := tt.ext.getDownloadURL(); got != tt.want {
			t.Errorf("[%d] getDownloadURL() = %q, want %q", i, got, tt.want)
		}
	}
}

func TestStoreExtensionGetIconURL(t *testing.T) {
	tests := []struct{ ext storeExtension; want string }{
		{storeExtension{IconURL: "a"}, "a"},
		{storeExtension{IconURLAlt: "b"}, "b"},
		{storeExtension{}, ""},
	}
	for i, tt := range tests {
		if got := tt.ext.getIconURL(); got != tt.want {
			t.Errorf("[%d] getIconURL() = %q, want %q", i, got, tt.want)
		}
	}
}

func TestStoreExtensionGetMinAppVersion(t *testing.T) {
	tests := []struct{ ext storeExtension; want string }{
		{storeExtension{MinAppVersion: "1.0"}, "1.0"},
		{storeExtension{MinAppVersionAlt: "2.0"}, "2.0"},
		{storeExtension{}, ""},
	}
	for i, tt := range tests {
		if got := tt.ext.getMinAppVersion(); got != tt.want {
			t.Errorf("[%d] getMinAppVersion() = %q, want %q", i, got, tt.want)
		}
	}
}

func TestToResponse(t *testing.T) {
	ext := &storeExtension{
		ID: "e1", Name: "ext", DisplayName: "Extension",
		Version: "1.0.0", Description: "desc",
		DownloadURL: "https://dl.example.com/ext.zip",
		IconURL: "https://example.com/icon.png",
		Category: CategoryUtility, Tags: []string{"a", "b"},
		Downloads: 42, UpdatedAt: "2024-06-01", MinAppVersion: "3.0",
	}
	resp := ext.toResponse()
	if resp.ID != "e1" { t.Error("ID mismatch") }
	if resp.Name != "ext" { t.Error("Name mismatch") }
	if resp.DisplayName != "Extension" { t.Error("DisplayName mismatch") }
	if resp.Version != "1.0.0" { t.Error("Version mismatch") }
	if resp.Description != "desc" { t.Error("Description mismatch") }
	if resp.DownloadURL != "https://dl.example.com/ext.zip" { t.Error("DownloadURL mismatch") }
	if resp.IconURL != "https://example.com/icon.png" { t.Error("IconURL mismatch") }
	if resp.Category != CategoryUtility { t.Error("Category mismatch") }
	if len(resp.Tags) != 2 || resp.Tags[0] != "a" { t.Error("Tags mismatch") }
	if resp.Downloads != 42 { t.Error("Downloads mismatch") }
	if resp.UpdatedAt != "2024-06-01" { t.Error("UpdatedAt mismatch") }
	if resp.MinAppVersion != "3.0" { t.Error("MinAppVersion mismatch") }
	if resp.IsInstalled { t.Error("IsInstalled should be false") }
	if resp.HasUpdate { t.Error("HasUpdate should be false") }
}

func TestToResponseNilTags(t *testing.T) {
	resp := (&storeExtension{ID: "e1", Name: "n", Category: "cat"}).toResponse()
	if resp.Tags != nil {
		t.Error("Tags should be nil when source Tags is nil")
	}
}

func TestNew(t *testing.T) {
	mgr := manager.NewManager()
	cacheDir := t.TempDir()
	s := New(mgr, cacheDir)
	if s.manager != mgr { t.Error("manager not set") }
	if s.registryURL != DefaultRegistryURL { t.Error("registryURL mismatch") }
	if s.cacheDir != cacheDir { t.Error("cacheDir mismatch") }
	if s.cacheTTL != cacheTTL { t.Error("cacheTTL mismatch") }
}

func TestNewEmptyCacheDir(t *testing.T) {
	s := New(manager.NewManager(), "")
	if s.cacheDir != "" { t.Error("cacheDir should be empty") }
}

func TestGetCategories(t *testing.T) {
	s := &Store{}
	cats := s.GetCategories()
	want := []string{CategoryMetadata, CategoryDownload, CategoryUtility, CategoryLyrics, CategoryIntegration}
	if len(cats) != len(want) { t.Fatalf("len=%d want=%d", len(cats), len(want)) }
	for i, c := range cats {
		if c != want[i] { t.Errorf("cat[%d]=%q want=%q", i, c, want[i]) }
	}
}
