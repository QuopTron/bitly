package deezer

import (
	"net/http"
	"testing"
)

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{
			Data: []Track{
				{ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
					Artist: ArtistRef{ID: 456, Name: "Test Artist"},
					Album:  AlbumRef{ID: 789, Title: "Test Album", Cover: "https://cover.url/1"}},
			},
			Total: 1,
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
	if r.ID != "deezer:123" {
		t.Errorf("ID: expected deezer:123, got %s", r.ID)
	}
	if r.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.Album != "Test Album" {
		t.Errorf("Album: expected Test Album, got %s", r.Album)
	}
	if r.Duration != 200 {
		t.Errorf("Duration: expected 200, got %d", r.Duration)
	}
	if r.ISRC != "USABC123" {
		t.Errorf("ISRC: expected USABC123, got %s", r.ISRC)
	}
	if r.Provider != "deezer" {
		t.Errorf("Provider: expected deezer, got %s", r.Provider)
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{Data: []Track{}, Total: 0}), nil
	})
	results, err := c.SearchTracks("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"data": []map[string]interface{}{
				{"id": 789, "title": "Test Album", "cover": "https://cover.url/2",
					"artist": map[string]interface{}{"id": 456, "name": "Test Artist"}},
			}, "total": 1,
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
	if r.ID != "deezer:789" {
		t.Errorf("ID: expected deezer:789, got %s", r.ID)
	}
	if r.Title != "Test Album" {
		t.Errorf("Title: expected Test Album, got %s", r.Title)
	}
	if r.Provider != "deezer" {
		t.Errorf("Provider: expected deezer, got %s", r.Provider)
	}
}

func TestSearchAlbums_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"data": []map[string]interface{}{}, "total": 0}), nil
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
		return okJSON(map[string]interface{}{
			"data": []map[string]interface{}{
				{"id": 456, "name": "Test Artist", "picture": "https://pic.url/1"},
			}, "total": 1,
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
	if r.ID != "deezer:456" {
		t.Errorf("ID: expected deezer:456, got %s", r.ID)
	}
	if r.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", r.Name)
	}
}
