package spotify

import (
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestSearchTracks_Success(t *testing.T) {
	callCount := 0
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		callCount++
		if strings.Contains(req.URL.String(), "/api/token") {
			return okJSON(map[string]interface{}{
				"access_token": "mock-token",
				"token_type":   "Bearer",
				"expires_in":   3600,
			}), nil
		}
		return okJSON(map[string]interface{}{
			"tracks": map[string]interface{}{
				"items": []map[string]interface{}{
					{
						"id": "abc123", "name": "Test Track",
						"artists": []map[string]interface{}{
							{"id": "art1", "name": "Test Artist"},
						},
						"album": map[string]interface{}{
							"name": "Test Album",
							"images": []map[string]interface{}{
								{"url": "https://cover.url"},
							},
						},
						"duration_ms":   200000,
						"external_ids":  map[string]interface{}{"isrc": "USABC123"},
					},
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
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"tracks": map[string]interface{}{
				"items": []map[string]interface{}{},
			},
		}), nil
	})
	results, err := c.SearchTracks("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

func TestSearchTracks_HTTPError(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return &http.Response{
			StatusCode: http.StatusBadGateway,
			Body:       io.NopCloser(strings.NewReader(`{"error":"bad gateway"}`)),
			Header:     make(http.Header),
		}, nil
	})
	_, err := c.SearchTracks("test", 5)
	if err == nil {
		t.Fatal("expected HTTP error")
	}
}
