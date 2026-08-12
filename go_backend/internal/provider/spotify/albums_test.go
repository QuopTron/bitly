package spotify

import (
	"net/http"
	"testing"
)

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"albums": map[string]interface{}{
				"items": []map[string]interface{}{
					{"id": "album1", "name": "Test Album",
						"artists": []map[string]interface{}{
							{"id": "art1", "name": "Test Artist"},
						},
						"images":       []map[string]interface{}{{"url": "https://cover.url"}},
						"release_date": "2024-01-01", "total_tracks": 12},
				},
			},
		}), nil
	})
	results, err := c.SearchAlbums("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) == 0 {
		t.Fatal("expected 1 result, got 0")
	}
}

func TestSearchAlbums_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"albums": map[string]interface{}{
				"items": []map[string]interface{}{},
			},
		}), nil
	})
	results, err := c.SearchAlbums("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}
