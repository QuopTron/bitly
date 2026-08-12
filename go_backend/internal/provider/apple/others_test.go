package apple

import (
	"net/http"
	"strings"
	"testing"
)

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "types=albums") {
			t.Errorf("expected types=albums, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"albums": map[string]interface{}{
					"data": []map[string]interface{}{
						{"id": "album789",
							"attributes": map[string]interface{}{
								"name": "Test Album", "artistName": "Test Artist",
								"releaseDate": "2024-01-01", "trackCount": 12,
								"artwork": map[string]interface{}{
									"url": "https://artwork.cdn/apple/{w}x{h}.jpg"},
							}},
					},
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
	if r.ID != "apple:album789" || r.Title != "Test Album" || r.Artist != "Test Artist" {
		t.Errorf("album mismatch")
	}
	if r.ReleaseDate != "2024-01-01" || r.TrackCount != 12 {
		t.Errorf("release/track mismatch")
	}
}

func TestSearchAlbums_NoToken(t *testing.T) {
	c := NewClient(nil, "", "us")
	_, err := c.SearchAlbums("test", 5)
	if err == nil || !strings.Contains(err.Error(), "no developer token") {
		t.Errorf("expected token error, got: %v", err)
	}
}

func TestSearchArtists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "types=artists") {
			t.Errorf("expected types=artists, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"artists": map[string]interface{}{
					"data": []map[string]interface{}{
						{"id": "artist456",
							"attributes": map[string]interface{}{
								"name": "Test Artist",
								"artwork": map[string]interface{}{
									"url": "https://artwork.cdn/apple/{w}x{h}.jpg"},
							}},
					},
				},
			},
		}), nil
	})
	results, err := c.SearchArtists("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	r := results[0]
	if r.ID != "apple:artist456" || r.Name != "Test Artist" {
		t.Errorf("artist mismatch")
	}
}
