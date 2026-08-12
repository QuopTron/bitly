package musicbrainz

import (
	"net/http"
	"strings"
	"testing"
)

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{
				{"id": "rec-123", "title": "Direct Track", "length": 200000,
					"artist-credit": []map[string]interface{}{
						{"name": "Some Artist",
							"artist": map[string]interface{}{"id": "art-1"}},
					}},
			},
		}), nil
	})
	track, err := c.GetTrack("rec-123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "mb:rec-123" || track.Title != "Direct Track" {
		t.Errorf("track mismatch")
	}
}

func TestGetTrack_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"recordings": []map[string]interface{}{}}), nil
	})
	_, err := c.GetTrack("nonexistent")
	if err == nil {
		t.Fatal("expected error for missing track")
	}
}

func TestGetTrackByISRC_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{
				{"id": "rec-isrc-123", "title": "ISRC Track", "length": 180000,
					"isrcs": []map[string]interface{}{{"id": "USABC1234567"}}},
			},
		}), nil
	})
	track, err := c.GetTrackByISRC("USABC1234567")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "mb:rec-isrc-123" {
		t.Errorf("ID: expected mb:rec-isrc-123, got %s", track.ID)
	}
}

func TestGetTrackByISRC_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"recordings": []map[string]interface{}{}}), nil
	})
	_, err := c.GetTrackByISRC("USNONEXISTENT")
	if err == nil {
		t.Fatal("expected error for missing ISRC")
	}
}

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/release/release-789") {
			t.Errorf("expected /release/release-789, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id": "release-789", "title": "Direct Album", "date": "2024-06-01",
			"track-count": 10,
			"artist-credit": []map[string]interface{}{
				{"name": "Album Artist",
					"artist": map[string]interface{}{"id": "art-2"}},
			},
		}), nil
	})
	album, err := c.GetAlbum("release-789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "mb:release-789" || album.Title != "Direct Album" || album.Artist != "Album Artist" {
		t.Errorf("album mismatch")
	}
}

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/artist/artist-456") {
			t.Errorf("expected /artist/artist-456, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id": "artist-456", "name": "Direct Artist",
		}), nil
	})
	artist, err := c.GetArtist("artist-456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "mb:artist-456" || artist.Name != "Direct Artist" {
		t.Errorf("artist mismatch")
	}
}
