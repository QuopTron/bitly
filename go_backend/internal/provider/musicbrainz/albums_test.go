package musicbrainz

import (
	"net/http"
	"strings"
	"testing"
)

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/release") {
			t.Errorf("expected /release, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"releases": []map[string]interface{}{
				{"id": "release-789", "title": "Test Album", "date": "2024-01-15",
					"track-count": 12,
					"artist-credit": []map[string]interface{}{
						{"name": "Test Artist",
							"artist": map[string]interface{}{"id": "artist-456"}},
					}},
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
	if r.ID != "mb:release-789" || r.Title != "Test Album" || r.Artist != "Test Artist" {
		t.Errorf("album mismatch")
	}
}

func TestSearchAlbums_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"releases": []map[string]interface{}{}}), nil
	})
	results, err := c.SearchAlbums("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}
