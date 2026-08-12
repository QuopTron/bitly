package apple

import (
	"net/http"
	"strings"
	"testing"
)

func TestSearchTracks_NoToken(t *testing.T) {
	c := NewClient(nil, "", "us")
	_, err := c.SearchTracks("test", 5)
	if err == nil || !strings.Contains(err.Error(), "no developer token") {
		t.Errorf("expected token error, got: %v", err)
	}
}

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "types=songs") {
			t.Errorf("expected types=songs, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"songs": map[string]interface{}{
					"data": []map[string]interface{}{
						{"id": "song123",
							"attributes": map[string]interface{}{
								"name": "Test Song", "artistName": "Test Artist",
								"albumName": "Test Album", "durationInMillis": 200000,
								"isrc": "USABC123",
								"artwork": map[string]interface{}{
									"url": "https://artwork.cdn/apple/{w}x{h}.jpg"},
							}},
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
	r := results[0]
	if r.ID != "apple:song123" {
		t.Errorf("ID: expected apple:song123, got %s", r.ID)
	}
	if r.Title != "Test Song" || r.Artist != "Test Artist" || r.Album != "Test Album" {
		t.Errorf("metadata mismatch")
	}
	if r.ISRC != "USABC123" || r.Provider != "apple" {
		t.Errorf("ISRC/Provider mismatch")
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"songs": map[string]interface{}{"data": []map[string]interface{}{}},
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
