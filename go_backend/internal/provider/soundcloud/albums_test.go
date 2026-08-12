package soundcloud

import (
	"net/http"
	"strings"
	"testing"
)

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/playlists") {
			t.Errorf("expected /search/playlists, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id": 456, "title": "Test Album",
					"artwork_url": "https://i1.sndcdn.com/artworks-album-t500x500.jpg",
					"track_count": 12, "is_album": true,
					"user": map[string]interface{}{"id": 789, "username": "Test Artist"},
				},
			},
		}), nil
	})
	results, err := c.SearchAlbums("test", 5)
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
	if r.Title != "Test Album" {
		t.Errorf("Title: expected Test Album, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.TrackCount != 12 {
		t.Errorf("TrackCount: expected 12, got %d", r.TrackCount)
	}
}

func TestSearchAlbums_FiltersNonAlbums(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id": 456, "title": "A Playlist", "track_count": 50, "is_album": false,
					"user": map[string]interface{}{"id": 789, "username": "Test User"},
				},
			},
		}), nil
	})
	results, err := c.SearchAlbums("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 (is_album=false), got %d", len(results))
	}
}
