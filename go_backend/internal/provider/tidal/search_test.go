package tidal

import (
	"net/http"
	"strings"
	"testing"
)

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/tracks") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(SearchResponse{
			Items: []Track{{ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
				Artist: ArtistRef{ID: 456, Name: "Test Artist"},
				Album:  AlbumRef{ID: 789, Title: "Test Album", Cover: "https://cover.url/1"},
			}},
			TotalCount: 1,
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
	if r.ID != "tidal:123" || r.Title != "Test Track" || r.Artist != "Test Artist" {
		t.Errorf("track mismatch")
	}
	if r.ISRC != "USABC123" || r.Provider != "tidal" {
		t.Errorf("ISRC/Provider mismatch")
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{Items: []Track{}, TotalCount: 0}), nil
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
		return errJSON(401, "unauthorized"), nil
	})
	_, err := c.SearchTracks("test", 5)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func TestSearchTracks_LimitClamping(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{Items: []Track{}, TotalCount: 0}), nil
	})
	_, _ = c.SearchTracks("test", 0)
	_, _ = c.SearchTracks("test", 200)
}

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/albums") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(AlbumSearchResponse{
			Items: []Album{{ID: 789, Title: "Test Album", ReleaseDate: "2024-01-01",
				Cover: "https://cover.url/2", TrackCount: 12,
				Artist: ArtistRef{ID: 456, Name: "Test Artist"}},
			},
			TotalCount: 1,
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
	if r.ID != "tidal:789" || r.Title != "Test Album" || r.Artist != "Test Artist" {
		t.Errorf("album mismatch")
	}
}

func TestSearchAlbums_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(AlbumSearchResponse{Items: []Album{}, TotalCount: 0}), nil
	})
	results, err := c.SearchAlbums("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

func TestSearchArtists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/artists") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(ArtistSearchResponse{
			Items: []Artist{{ID: 456, Name: "Test Artist", PictureURL: "https://pic.url/1"}},
			TotalCount: 1,
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
	if r.ID != "tidal:456" || r.Name != "Test Artist" {
		t.Errorf("artist mismatch")
	}
}

func TestSearchArtists_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(ArtistSearchResponse{Items: []Artist{}, TotalCount: 0}), nil
	})
	results, err := c.SearchArtists("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}
