package apple

import (
	"net/http"
	"strings"
	"testing"
)

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/songs/song123") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"data": []map[string]interface{}{
				{"id": "song123",
					"attributes": map[string]interface{}{
						"name": "Test Song", "artistName": "Test Artist",
						"albumName": "Test Album", "durationInMillis": 200000,
						"isrc": "USABC123",
						"artwork": map[string]interface{}{
							"url": "https://artwork.cdn/apple/{w}x{h}.jpg"},
					}},
			},
		}), nil
	})
	track, err := c.GetTrack("song123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "apple:song123" || track.Title != "Test Song" || track.ISRC != "USABC123" {
		t.Errorf("track mismatch")
	}
}

func TestGetTrack_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"data": []map[string]interface{}{}}), nil
	})
	_, err := c.GetTrack("nonexistent")
	if err == nil {
		t.Fatal("expected error for missing track")
	}
}

func TestGetTrack_NoToken(t *testing.T) {
	c := NewClient(nil, "", "us")
	_, err := c.GetTrack("song123")
	if err == nil || !strings.Contains(err.Error(), "no developer token") {
		t.Errorf("expected token error, got: %v", err)
	}
}

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/albums/album789") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"data": []map[string]interface{}{
				{"id": "album789",
					"attributes": map[string]interface{}{
						"name": "Test Album", "artistName": "Test Artist",
						"releaseDate": "2024-01-01", "trackCount": 12,
						"artwork": map[string]interface{}{
							"url": "https://artwork.cdn/apple/{w}x{h}.jpg"},
					}},
			},
		}), nil
	})
	album, err := c.GetAlbum("album789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "apple:album789" || album.Title != "Test Album" || album.Artist != "Test Artist" {
		t.Errorf("album mismatch")
	}
}

func TestGetAlbum_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"data": []map[string]interface{}{}}), nil
	})
	_, err := c.GetAlbum("nonexistent")
	if err == nil {
		t.Fatal("expected error for missing album")
	}
}

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/artists/artist456") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"data": []map[string]interface{}{
				{"id": "artist456",
					"attributes": map[string]interface{}{
						"name": "Test Artist",
						"artwork": map[string]interface{}{
							"url": "https://artwork.cdn/apple/{w}x{h}.jpg"},
					}},
			},
		}), nil
	})
	artist, err := c.GetArtist("artist456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "apple:artist456" || artist.Name != "Test Artist" {
		t.Errorf("artist mismatch")
	}
}

func TestGetTrackByISRC_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"songs": map[string]interface{}{
					"data": []map[string]interface{}{
						{"id": "song123",
							"attributes": map[string]interface{}{
								"name": "Test Song", "isrc": "USABC123"}},
					},
				},
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
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"songs": map[string]interface{}{"data": []map[string]interface{}{}},
			},
		}), nil
	})
	_, err := c.GetTrackByISRC("USNONEXISTENT")
	if err == nil {
		t.Fatal("expected error for missing ISRC")
	}
}
