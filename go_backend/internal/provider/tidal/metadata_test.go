package tidal

import (
	"net/http"
	"strings"
	"testing"
)

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/tracks/123") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(Track{
			ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
			TrackNumber: 3, Explicit: false,
			Artist: ArtistRef{ID: 456, Name: "Test Artist"},
			Album:  AlbumRef{ID: 789, Title: "Test Album", Cover: "https://cover.url/1"},
		}), nil
	})
	track, err := c.GetTrack("123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "tidal:123" || track.Title != "Test Track" || track.Artist != "Test Artist" {
		t.Errorf("track mismatch")
	}
	if track.ISRC != "USABC123" || track.Duration != 200 {
		t.Errorf("ISRC/Duration mismatch")
	}
}

func TestGetTrack_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return errJSON(404, "not found"), nil
	})
	_, err := c.GetTrack("999")
	if err == nil {
		t.Fatal("expected error for missing track")
	}
}

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/albums/789") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(Album{
			ID: 789, Title: "Test Album", ReleaseDate: "2024-01-01",
			Cover: "https://cover.url/2", TrackCount: 12,
			Artist: ArtistRef{ID: 456, Name: "Test Artist"},
		}), nil
	})
	album, err := c.GetAlbum("789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "tidal:789" || album.Title != "Test Album" || album.Artist != "Test Artist" {
		t.Errorf("album mismatch")
	}
	if album.TrackCount != 12 {
		t.Errorf("TrackCount: expected 12, got %d", album.TrackCount)
	}
}

func TestGetAlbum_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return errJSON(404, "not found"), nil
	})
	_, err := c.GetAlbum("999")
	if err == nil {
		t.Fatal("expected error for missing album")
	}
}

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/artists/456") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(Artist{
			ID: 456, Name: "Test Artist", PictureURL: "https://pic.url/1",
		}), nil
	})
	artist, err := c.GetArtist("456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "tidal:456" || artist.Name != "Test Artist" {
		t.Errorf("artist mismatch")
	}
}

func TestGetArtist_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return errJSON(404, "not found"), nil
	})
	_, err := c.GetArtist("999")
	if err == nil {
		t.Fatal("expected error for missing artist")
	}
}

func TestGetTrackByISRC_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{
			Items: []Track{{ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
				Artist: ArtistRef{ID: 456, Name: "Test Artist"},
				Album:  AlbumRef{ID: 789, Title: "Test Album"}},
			},
			TotalCount: 1,
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
		return okJSON(SearchResponse{Items: []Track{}, TotalCount: 0}), nil
	})
	_, err := c.GetTrackByISRC("USNONEXISTENT")
	if err == nil {
		t.Fatal("expected error for missing ISRC")
	}
}
