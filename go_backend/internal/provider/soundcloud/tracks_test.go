package soundcloud

import (
	"net/http"
	"strings"
	"testing"
)

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/tracks") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		if !strings.Contains(req.URL.RawQuery, "client_id=test-client-id") {
			t.Errorf("expected client_id param, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id": 123456, "title": "Test Track", "duration": 240000, "genre": "Pop",
					"user":       map[string]interface{}{"id": 789, "username": "Test Artist"},
					"artwork_url": "https://i1.sndcdn.com/artworks-test-t500x500.jpg",
				},
			},
		}), nil
	})
	results, err := c.SearchTracks("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	r := results[0]
	if r.ID != "sc:123456" {
		t.Errorf("ID: expected sc:123456, got %s", r.ID)
	}
	if r.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.Duration != 240000 {
		t.Errorf("Duration: expected 240000, got %d", r.Duration)
	}
	if !strings.Contains(r.CoverURL, "artworks-test") {
		t.Errorf("CoverURL unexpected: %s", r.CoverURL)
	}
	if r.Provider != "soundcloud" {
		t.Errorf("Provider: expected soundcloud, got %s", r.Provider)
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"collection": []map[string]interface{}{}}), nil
	})
	results, err := c.SearchTracks("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

func TestSearchTracks_NoClientID(t *testing.T) {
	c := NewClient(nil, "")
	_, err := c.SearchTracks("test", 5)
	if err == nil || !strings.Contains(err.Error(), "client_id not set") {
		t.Errorf("expected client_id error, got: %v", err)
	}
}

func TestSearchTracks_HTTPError(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return errSCResponse(500), nil
	})
	_, err := c.SearchTracks("test", 5)
	if err == nil {
		t.Fatal("expected HTTP error")
	}
}
