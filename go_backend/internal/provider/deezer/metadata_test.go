package deezer

import (
	"net/http"
	"testing"
)

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(Track{
			ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
			Artist: ArtistRef{ID: 456, Name: "Test Artist"},
			Album:  AlbumRef{ID: 789, Title: "Test Album", Cover: "https://cover.url/1"},
		}), nil
	})
	track, err := c.GetTrack("123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "deezer:123" {
		t.Errorf("ID: expected deezer:123, got %s", track.ID)
	}
	if track.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", track.Title)
	}
	if track.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", track.Artist)
	}
}

func TestGetTrack_InvalidID(t *testing.T) {
	c := mockClient(nil)
	_, err := c.GetTrack("abc")
	if err == nil {
		t.Fatal("expected error for invalid ID")
	}
}

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(Album{
			ID: 789, Title: "Test Album", ReleaseDate: "2024-01-01",
			CoverBig: "https://cover.url/2", TrackCount: 12,
			Artist: ArtistRef{ID: 456, Name: "Test Artist"},
		}), nil
	})
	album, err := c.GetAlbum("789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "deezer:789" {
		t.Errorf("ID: expected deezer:789, got %s", album.ID)
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

func TestGetAlbum_InvalidID(t *testing.T) {
	c := mockClient(nil)
	_, err := c.GetAlbum("abc")
	if err == nil {
		t.Fatal("expected error for invalid ID")
	}
}

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(Artist{
			ID: 456, Name: "Test Artist", PictureBig: "https://pic.url/1",
		}), nil
	})
	artist, err := c.GetArtist("456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "deezer:456" {
		t.Errorf("ID: expected deezer:456, got %s", artist.ID)
	}
	if artist.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", artist.Name)
	}
}

func TestGetTrackByISRC_Success(t *testing.T) {
	callCount := 0
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		callCount++
		if callCount == 1 {
			return okJSON(SearchResponse{
				Data: []Track{
					{ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
						Artist: ArtistRef{ID: 456, Name: "Test Artist"},
						Album:  AlbumRef{ID: 789, Title: "Test Album"}},
				},
				Total: 1,
			}), nil
		}
		return okJSON(Track{
			ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
			Artist: ArtistRef{ID: 456, Name: "Test Artist"},
			Album:  AlbumRef{ID: 789, Title: "Test Album"},
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
		return okJSON(SearchResponse{Data: []Track{}, Total: 0}), nil
	})
	_, err := c.GetTrackByISRC("USNONEXISTENT")
	if err == nil {
		t.Fatal("expected error for missing ISRC")
	}
}
