package deezer

import (
	"testing"
	"time"
)

func TestGetClient(t *testing.T) {
	c := GetClient()
	if c == nil {
		t.Fatal("expected non-nil Client")
	}
	if c.httpClient == nil {
		t.Error("expected non-nil httpClient")
	}
	if c.searchCache == nil {
		t.Error("expected initialized searchCache")
	}
	if c.albumCache == nil {
		t.Error("expected initialized albumCache")
	}
	if c.artistCache == nil {
		t.Error("expected initialized artistCache")
	}
	if c.isrcCache == nil {
		t.Error("expected initialized isrcCache")
	}
}

func TestGetClient_Singleton(t *testing.T) {
	c1 := GetClient()
	c2 := GetClient()
	if c1 != c2 {
		t.Error("GetClient should return the same instance")
	}
}

func TestGetClient_CacheCleanupInterval(t *testing.T) {
	c := GetClient()
	if c.cacheCleanupInterval != cacheCleanupInterval {
		t.Errorf("cacheCleanupInterval = %v, want %v", c.cacheCleanupInterval, cacheCleanupInterval)
	}
}

func TestCacheEntry_Expired(t *testing.T) {
	entry := &cacheEntry{
		data:      "test",
		expiresAt: time.Now().Add(-time.Hour),
	}
	if !entry.isExpired() {
		t.Error("expected entry to be expired")
	}
}

func TestCacheEntry_NotExpired(t *testing.T) {
	entry := &cacheEntry{
		data:      "test",
		expiresAt: time.Now().Add(time.Hour),
	}
	if entry.isExpired() {
		t.Error("expected entry to not be expired")
	}
}

func TestClient_Constants(t *testing.T) {
	if baseURL != "https://api.deezer.com/2.0" {
		t.Errorf("baseURL = %q", baseURL)
	}
	if cacheTTL != 10*time.Minute {
		t.Errorf("cacheTTL = %v", cacheTTL)
	}
	if maxParallelISRC != 10 {
		t.Errorf("maxParallelISRC = %d", maxParallelISRC)
	}
	if maxRetries != 2 {
		t.Errorf("maxRetries = %d", maxRetries)
	}
}

func TestClient_URLTemplates(t *testing.T) {
	if searchURL != baseURL+"/search" {
		t.Errorf("searchURL = %q", searchURL)
	}
	if trackURL != baseURL+"/track/%s" {
		t.Errorf("trackURL = %q", trackURL)
	}
	if albumURL != baseURL+"/album/%s" {
		t.Errorf("albumURL = %q", albumURL)
	}
	if artistURL != baseURL+"/artist/%s" {
		t.Errorf("artistURL = %q", artistURL)
	}
}

func TestGetClient_CacheCleanupDefaults(t *testing.T) {
	c := GetClient()
	if c.cacheCleanupInterval <= 0 {
		t.Error("expected cacheCleanupInterval to be positive")
	}
}
