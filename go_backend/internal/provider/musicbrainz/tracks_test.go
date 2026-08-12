package musicbrainz

import (
	"net/http"
	"strings"
	"testing"
)

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/recording") {
			t.Errorf("expected /recording, got: %s", req.URL.Path)
		}
		if !strings.Contains(req.URL.RawQuery, "fmt=json") {
			t.Errorf("expected fmt=json, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{
				{"id": "abc-123-def", "title": "Test Song", "length": 240000,
					"isrcs": []map[string]interface{}{{"id": "USABC1234567"}},
					"artist-credit": []map[string]interface{}{
						{"name": "Test Artist",
							"artist": map[string]interface{}{"id": "artist-456"}},
					},
					"releases": []map[string]interface{}{
						{"id": "release-789", "title": "Test Album"},
					},
				},
			},
		}), nil
	})
	results, err := c.SearchTracks("Test Song", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	r := results[0]
	if r.ID != "mb:abc-123-def" || r.Title != "Test Song" || r.Artist != "Test Artist" {
		t.Errorf("track mismatch")
	}
	if r.ISRC != "USABC1234567" || r.Provider != "musicbrainz" {
		t.Errorf("ISRC/Provider mismatch")
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"recordings": []map[string]interface{}{}}), nil
	})
	results, err := c.SearchTracks("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

func TestSearchTracks_NoArtistCredit(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{
				{"id": "abc-123", "title": "Unknown Artist Song", "length": 200000},
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
	if r.Artist != "" {
		t.Errorf("Artist should be empty, got: %s", r.Artist)
	}
	if r.Album != "" {
		t.Errorf("Album should be empty, got: %s", r.Album)
	}
}
