package spotify

import (
	"net/http"
	"testing"
)

func TestSearchArtists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"artists": map[string]interface{}{
				"items": []map[string]interface{}{
					{"id": "art1", "name": "Test Artist",
						"images": []map[string]interface{}{{"url": "https://pic.url"}}},
				},
			},
		}), nil
	})
	results, err := c.SearchArtists("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) == 0 {
		t.Fatal("expected 1 result, got 0")
	}
}

func TestSearchArtists_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"artists": map[string]interface{}{
				"items": []map[string]interface{}{},
			},
		}), nil
	})
	results, err := c.SearchArtists("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}
