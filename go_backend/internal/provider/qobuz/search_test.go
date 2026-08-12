package qobuz

import (
	"net/http"
	"testing"
)

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{
			Tracks: &struct {
				Items []Track `json:"items"`
				Total int     `json:"total"`
			}{
				Items: []Track{
					{ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
						Performer: &Artist{ID: 456, Name: "Test Artist"},
						Album:     &Album{ID: 789, Title: "Test Album", Image: Image{Large: "https://cover.url/1"}},
					},
				},
				Total: 1,
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
	if r.ID != "qobuz:123" {
		t.Errorf("ID: expected qobuz:123, got %s", r.ID)
	}
	if r.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.ISRC != "USABC123" {
		t.Errorf("ISRC: expected USABC123, got %s", r.ISRC)
	}
	if r.Provider != "qobuz" {
		t.Errorf("Provider: expected qobuz, got %s", r.Provider)
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{}), nil
	})
	results, err := c.SearchTracks("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if results != nil {
		t.Errorf("expected nil, got %v", results)
	}
}

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{
			Albums: &struct {
				Items []Album `json:"items"`
				Total int     `json:"total"`
			}{
				Items: []Album{
					{ID: 789, Title: "Test Album", ReleaseDate: "2024-01-01",
						TrackCount: 12, Image: Image{Large: "https://cover.url/2"},
						Artist: &Artist{ID: 456, Name: "Test Artist"}},
				},
				Total: 1,
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
	if r.ID != "qobuz:789" {
		t.Errorf("ID: expected qobuz:789, got %s", r.ID)
	}
	if r.Title != "Test Album" {
		t.Errorf("Title: expected Test Album, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.ReleaseDate != "2024-01-01" {
		t.Errorf("ReleaseDate: expected 2024-01-01, got %s", r.ReleaseDate)
	}
	if r.TrackCount != 12 {
		t.Errorf("TrackCount: expected 12, got %d", r.TrackCount)
	}
}

func TestSearchAlbums_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{}), nil
	})
	results, err := c.SearchAlbums("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if results != nil {
		t.Errorf("expected nil, got %v", results)
	}
}

func TestSearchArtists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{
			Artists: &struct {
				Items []Artist `json:"items"`
				Total int      `json:"total"`
			}{
				Items: []Artist{
					{ID: 456, Name: "Test Artist", Image: Image{Large: "https://pic.url/1"}},
				},
				Total: 1,
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
	if r.ID != "qobuz:456" {
		t.Errorf("ID: expected qobuz:456, got %s", r.ID)
	}
	if r.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", r.Name)
	}
}
