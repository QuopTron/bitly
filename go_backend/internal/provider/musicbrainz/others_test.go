package musicbrainz

import (
	"net/http"
	"strings"
	"testing"
)

func TestSearchArtists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/artist") {
			t.Errorf("expected /artist, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"artists": []map[string]interface{}{
				{"id": "artist-456", "name": "Test Artist"},
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
	if r.ID != "mb:artist-456" || r.Name != "Test Artist" || r.Provider != "musicbrainz" {
		t.Errorf("artist mismatch")
	}
}

func TestSearchPlaylists_ReturnsNil(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		t.Error("SearchPlaylists should not make HTTP requests (not supported)")
		return nil, nil
	})
	results, err := c.SearchPlaylists("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if results != nil {
		t.Errorf("expected nil results, got %v", results)
	}
}
