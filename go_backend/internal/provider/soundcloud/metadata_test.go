package soundcloud

import (
	"net/http"
	"strings"
	"testing"
)

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/tracks/123456") {
			t.Errorf("expected /tracks/123456, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id": 123456, "title": "Test Track", "duration": 240000, "genre": "Pop",
			"artwork_url": "https://i1.sndcdn.com/artworks-track-t500x500.jpg",
			"stream_url":  "https://api.soundcloud.com/tracks/123456/stream",
			"user":        map[string]interface{}{"id": 789, "username": "Test Artist"},
			"media": map[string]interface{}{
				"transcodings": []map[string]interface{}{
					{"url": "https://api.soundcloud.com/tracks/123456/transcodings/abc",
						"format": map[string]interface{}{"protocol": "progressive"}},
				},
			},
		}), nil
	})
	track, err := c.GetTrack("123456")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "sc:123456" {
		t.Errorf("ID: expected sc:123456, got %s", track.ID)
	}
	if track.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", track.Title)
	}
	if track.Duration != 240000 {
		t.Errorf("Duration: expected 240000, got %d", track.Duration)
	}
}

func TestGetTrack_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return errSCResponse(404), nil
	})
	_, err := c.GetTrack("nonexistent")
	if err == nil {
		t.Fatal("expected error for missing track")
	}
}

func TestGetTrack_NoClientID(t *testing.T) {
	c := NewClient(nil, "")
	_, err := c.GetTrack("123456")
	if err == nil || !strings.Contains(err.Error(), "client_id not set") {
		t.Errorf("expected client_id error, got: %v", err)
	}
}

func TestGetTrackByISRC_ReturnsError(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		t.Error("GetTrackByISRC should not make HTTP requests (not supported)")
		return nil, nil
	})
	_, err := c.GetTrackByISRC("USABC123")
	if err == nil {
		t.Fatal("expected error for ISRC lookup")
	}
	if !strings.Contains(err.Error(), "ISRC lookup not available") {
		t.Errorf("expected ISRC error, got: %v", err)
	}
}

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/playlists/456") {
			t.Errorf("expected /playlists/456, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id": 456, "title": "Test Album",
			"artwork_url": "https://i1.sndcdn.com/artworks-album-t500x500.jpg",
			"track_count": 12, "description": "An album description",
			"user": map[string]interface{}{"id": 789, "username": "Test Artist"},
		}), nil
	})
	album, err := c.GetAlbum("456")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "sc:456" {
		t.Errorf("ID: expected sc:456, got %s", album.ID)
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
		if !strings.Contains(req.URL.String(), "/users/789") {
			t.Errorf("expected /users/789, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id": 789, "username": "Test Artist",
			"avatar_url": "https://i1.sndcdn.com/avatars-user-t500x500.jpg",
			"description": "A great artist", "followers_count": 1500, "track_count": 25,
		}), nil
	})
	artist, err := c.GetArtist("789")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "sc:789" {
		t.Errorf("ID: expected sc:789, got %s", artist.ID)
	}
	if artist.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", artist.Name)
	}
	if !strings.Contains(artist.PictureURL, "avatars-user") {
		t.Errorf("PictureURL unexpected: %s", artist.PictureURL)
	}
}
