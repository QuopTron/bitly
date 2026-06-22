package qobuz

import (
	"encoding/json"
	"net/http"
	"testing"
	"time"
)

func TestSearchByISRC_Empty(t *testing.T) {
	c := &Client{
		cache:       make(map[string]*cacheEntry),
		stopCleanup: make(chan struct{}),
	}
	_, err := c.SearchByISRC("")
	if err == nil || err.Error() != "empty ISRC" {
		t.Fatalf("expected 'empty ISRC' error, got %v", err)
	}
}

func TestSearchByISRC_WithServer(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": true,
			"data": map[string]interface{}{
				"query": "USABC123",
				"tracks": map[string]interface{}{
					"items": []map[string]interface{}{
						{
							"id": 999, "title": "Test Song", "duration": 200,
							"track_number": 1, "isrc": "USABC123",
							"performer": map[string]interface{}{"id": 1, "name": "Artist"},
							"album":     map[string]interface{}{"id": "1", "title": "Album"},
						},
					},
					"total": 1,
				},
			},
		})
	})
	c := testClient(handler)
	id, err := c.SearchByISRC("USABC123")
	if err != nil {
		t.Fatal(err)
	}
	if id != "999" {
		t.Errorf("expected track ID 999, got %q", id)
	}
}

func TestDownloadURL_NoQuality(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": true,
			"data":    map[string]string{"url": "https://example.com/dl"},
		})
	})
	c := testClient(handler)
	url, err := c.DownloadURL("123", "")
	if err != nil {
		t.Fatal(err)
	}
	if url != "https://example.com/dl" {
		t.Errorf("url = %q", url)
	}
}

func TestDownloadURL_CacheHit(t *testing.T) {
	c := &Client{
		cache:       make(map[string]*cacheEntry),
		stopCleanup: make(chan struct{}),
	}
	c.setCache("dl:123:", "https://cached.url/dl", 5*time.Minute)
	url, err := c.DownloadURL("123", "")
	if err != nil {
		t.Fatal(err)
	}
	if url != "https://cached.url/dl" {
		t.Errorf("url = %q", url)
	}
}

func TestGetAlbum_NilClient(t *testing.T) {
	c := testClient(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	_, err := c.GetAlbum("nonexistent")
	if err == nil {
		t.Error("expected error with bad server")
	}
}
