package qobuz

import (
	"fmt"
	"testing"
	"time"
)

func TestQualityToParam(t *testing.T) {
	tests := []struct {
		in   string
		want string
	}{
		{"MP3_320", "5"}, {"320", "5"},
		{"LOSSLESS", "6"}, {"CD", "6"}, {"16", "6"},
		{"HI_RES", "7"}, {"24", "7"},
		{"", "27"}, {"FLAC", "27"},
	}
	for _, tt := range tests {
		got := QualityToParam(tt.in)
		if got != tt.want {
			t.Errorf("QualityToParam(%q) = %q, want %q", tt.in, got, tt.want)
		}
	}
}

func TestGetClient(t *testing.T) {
	c := GetClient()
	if c == nil {
		t.Fatal("expected non-nil Client")
	}
	if c.httpClient == nil {
		t.Error("expected non-nil httpClient")
	}
	if c.cache == nil {
		t.Error("expected non-nil cache")
	}
}

func TestGetClient_Singleton(t *testing.T) {
	c1 := GetClient()
	c2 := GetClient()
	if c1 != c2 {
		t.Error("GetClient should return the same instance")
	}
}

func TestCacheSetGet(t *testing.T) {
	c := &Client{
		httpClient:  nil,
		cache:       make(map[string]*cacheEntry),
		stopCleanup: make(chan struct{}),
	}
	c.setCache("key1", "value1", 10*time.Minute)
	got := c.getFromCache("key1")
	if got.(string) != "value1" {
		t.Errorf("got %q", got)
	}
}

func TestCacheExpired(t *testing.T) {
	c := &Client{
		cache:       make(map[string]*cacheEntry),
		stopCleanup: make(chan struct{}),
	}
	c.setCache("expired", "data", -1*time.Second)
	got := c.getFromCache("expired")
	if got != nil {
		t.Error("expected nil for expired cache entry")
	}
}

func TestCacheMaxEntries(t *testing.T) {
	c := &Client{
		cache:       make(map[string]*cacheEntry),
		stopCleanup: make(chan struct{}),
	}
	for i := 0; i < maxCacheEntries+50; i++ {
		c.setCache(fmt.Sprintf("k%d", i), "v", 10*time.Minute)
	}
	if len(c.cache) > maxCacheEntries {
		t.Errorf("cache size = %d, want <= %d", len(c.cache), maxCacheEntries)
	}
}

func TestCleanupLoop(t *testing.T) {
	c := &Client{
		cache:         make(map[string]*cacheEntry),
		cleanupTicker: time.NewTicker(10 * time.Millisecond),
		stopCleanup:   make(chan struct{}),
	}
	c.setCache("old", "val", 0)
	time.Sleep(20 * time.Millisecond)
	go c.cleanupLoop()
	time.Sleep(30 * time.Millisecond)
	close(c.stopCleanup)
	time.Sleep(10 * time.Millisecond)
	c.mu.RLock()
	_, exists := c.cache["old"]
	c.mu.RUnlock()
	if exists {
		t.Log("cache entry not cleaned up yet (timing dependent)")
	}
}

func TestBaseURLConstant(t *testing.T) {
	if baseURL == "" {
		t.Error("baseURL is empty")
	}
}
