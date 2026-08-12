package soundcloud

import (
	"net/http"
	"strings"
	"testing"
)

func TestSearchPlaylists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/playlists") {
			t.Errorf("expected /search/playlists, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id": 456, "title": "Test Playlist", "description": "A great playlist",
					"artwork_url": "https://i1.sndcdn.com/artworks-pl-t500x500.jpg",
					"track_count": 25,
					"user":        map[string]interface{}{"id": 789, "username": "Test Curator"},
				},
			},
		}), nil
	})
	results, err := c.SearchPlaylists("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	r := results[0]
	if r.ID != "sc:456" {
		t.Errorf("ID: expected sc:456, got %s", r.ID)
	}
	if r.Title != "Test Playlist" {
		t.Errorf("Title: expected Test Playlist, got %s", r.Title)
	}
	if r.Creator != "Test Curator" {
		t.Errorf("Creator: expected Test Curator, got %s", r.Creator)
	}
	if r.TrackCount != 25 {
		t.Errorf("TrackCount: expected 25, got %d", r.TrackCount)
	}
	if r.Description != "A great playlist" {
		t.Errorf("Description: expected 'A great playlist', got %s", r.Description)
	}
}
