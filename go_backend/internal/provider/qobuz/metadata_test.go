package qobuz

import (
	"net/http"
	"testing"
)

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(Track{
			ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
			Performer: &Artist{ID: 456, Name: "Test Artist"},
			Album:     &Album{ID: 789, Title: "Test Album", Image: Image{Large: "https://cover.url/1"}},
		}), nil
	})
	track, err := c.GetTrack("123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "qobuz:123" {
		t.Errorf("ID: expected qobuz:123, got %s", track.ID)
	}
	if track.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", track.Title)
	}
	if track.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", track.Artist)
	}
}

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(Album{
			ID: 789, Title: "Test Album", ReleaseDate: "2024-01-01",
			TrackCount: 12, Image: Image{Large: "https://cover.url/2"},
			Artist: &Artist{ID: 456, Name: "Test Artist"},
		}), nil
	})
	album, err := c.GetAlbum("789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "qobuz:789" {
		t.Errorf("ID: expected qobuz:789, got %s", album.ID)
	}
	if album.Title != "Test Album" {
		t.Errorf("Title: expected Test Album, got %s", album.Title)
	}
	if album.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", album.Artist)
	}
	if album.TrackCount != 12 {
		t.Errorf("TrackCount: expected 12, got %d", album.TrackCount)
	}
}

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(Artist{
			ID: 456, Name: "Test Artist", Image: Image{Large: "https://pic.url/1"},
		}), nil
	})
	artist, err := c.GetArtist("456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "qobuz:456" {
		t.Errorf("ID: expected qobuz:456, got %s", artist.ID)
	}
	if artist.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", artist.Name)
	}
}

func TestGetTrackByISRC_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{
			Tracks: &struct {
				Items []Track `json:"items"`
				Total int     `json:"total"`
			}{
				Items: []Track{
					{ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
						Performer: &Artist{ID: 456, Name: "Test Artist"},
						Album:     &Album{ID: 789, Title: "Test Album"}},
				},
				Total: 1,
			},
		}), nil
	})
	track, err := c.GetTrackByISRC("USABC123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ISRC != "USABC123" {
		t.Errorf("ISRC: expected USABC123, got %s", track.ISRC)
	}
}

func TestGetTrackByISRC_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{}), nil
	})
	_, err := c.GetTrackByISRC("USNONEXISTENT")
	if err == nil {
		t.Fatal("expected error for missing ISRC")
	}
}
