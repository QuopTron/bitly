package apple

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

// mockTransport implements http.RoundTripper for testing.
type mockTransport struct {
	roundTrip func(req *http.Request) (*http.Response, error)
}

func (m *mockTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	return m.roundTrip(req)
}

func mockClient(handler func(req *http.Request) (*http.Response, error)) *Client {
	return NewClient(&http.Client{Transport: &mockTransport{roundTrip: handler}}, "test-token", "us")
}

func okJSON(body interface{}) *http.Response {
	b, _ := json.Marshal(body)
	return &http.Response{
		StatusCode: http.StatusOK,
		Body:       io.NopCloser(strings.NewReader(string(b))),
		Header:     make(http.Header),
	}
}

func errJSON(status int, msg string) *http.Response {
	return &http.Response{
		StatusCode: status,
		Body:       io.NopCloser(strings.NewReader(`{"errors":[{"title":"`+msg+`"}]}`)),
		Header:     make(http.Header),
	}
}

func TestSearchTracks_NoToken(t *testing.T) {
	c := NewClient(nil, "", "us")
	_, err := c.SearchTracks("test", 5)
	if err == nil || !strings.Contains(err.Error(), "no developer token") {
		t.Errorf("expected token error, got: %v", err)
	}
}

// ─── SearchTracks ────────────────────────────────────────────────

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "types=songs") {
			t.Errorf("expected types=songs, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"songs": map[string]interface{}{
					"data": []map[string]interface{}{
						{
							"id": "song123",
							"attributes": map[string]interface{}{
								"name":             "Test Song",
								"artistName":       "Test Artist",
								"albumName":        "Test Album",
								"durationInMillis": 200000,
								"isrc":             "USABC123",
								"artwork": map[string]interface{}{
									"url": "https://artwork.cdn/apple/{w}x{h}.jpg",
								},
							},
						},
					},
				},
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
	if r.ID != "apple:song123" {
		t.Errorf("ID: expected apple:song123, got %s", r.ID)
	}
	if r.Title != "Test Song" {
		t.Errorf("Title: expected Test Song, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.Album != "Test Album" {
		t.Errorf("Album: expected Test Album, got %s", r.Album)
	}
	if r.Duration != 200000 {
		t.Errorf("Duration: expected 200000, got %d", r.Duration)
	}
	if r.ISRC != "USABC123" {
		t.Errorf("ISRC: expected USABC123, got %s", r.ISRC)
	}
	if !strings.Contains(r.CoverURL, "300x300") {
		t.Errorf("CoverURL should contain 300x300, got: %s", r.CoverURL)
	}
	if r.Provider != "apple" {
		t.Errorf("Provider: expected apple, got %s", r.Provider)
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"songs": map[string]interface{}{
					"data": []map[string]interface{}{},
				},
			},
		}), nil
	})
	results, err := c.SearchTracks("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

// ─── SearchAlbums ────────────────────────────────────────────────

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "types=albums") {
			t.Errorf("expected types=albums, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"albums": map[string]interface{}{
					"data": []map[string]interface{}{
						{
							"id": "album789",
							"attributes": map[string]interface{}{
								"name":       "Test Album",
								"artistName": "Test Artist",
								"artwork": map[string]interface{}{
									"url": "https://artwork.cdn/apple/{w}x{h}.jpg",
								},
								"releaseDate": "2024-01-01",
								"trackCount":  12,
							},
						},
					},
				},
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
	if r.ID != "apple:album789" {
		t.Errorf("ID: expected apple:album789, got %s", r.ID)
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
	if r.Provider != "apple" {
		t.Errorf("Provider: expected apple, got %s", r.Provider)
	}
}

func TestSearchAlbums_NoToken(t *testing.T) {
	c := NewClient(nil, "", "us")
	_, err := c.SearchAlbums("test", 5)
	if err == nil || !strings.Contains(err.Error(), "no developer token") {
		t.Errorf("expected token error, got: %v", err)
	}
}

// ─── SearchArtists ───────────────────────────────────────────────

func TestSearchArtists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "types=artists") {
			t.Errorf("expected types=artists, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"artists": map[string]interface{}{
					"data": []map[string]interface{}{
						{
							"id": "artist456",
							"attributes": map[string]interface{}{
								"name": "Test Artist",
								"artwork": map[string]interface{}{
									"url": "https://artwork.cdn/apple/{w}x{h}.jpg",
								},
							},
						},
					},
				},
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
	if r.ID != "apple:artist456" {
		t.Errorf("ID: expected apple:artist456, got %s", r.ID)
	}
	if r.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", r.Name)
	}
	if r.Provider != "apple" {
		t.Errorf("Provider: expected apple, got %s", r.Provider)
	}
}

// ─── GetTrack ────────────────────────────────────────────────────

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/songs/song123") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"data": []map[string]interface{}{
				{
					"id": "song123",
					"attributes": map[string]interface{}{
						"name":             "Test Song",
						"artistName":       "Test Artist",
						"albumName":        "Test Album",
						"durationInMillis": 200000,
						"isrc":             "USABC123",
						"artwork": map[string]interface{}{
							"url": "https://artwork.cdn/apple/{w}x{h}.jpg",
						},
					},
				},
			},
		}), nil
	})
	track, err := c.GetTrack("song123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "apple:song123" {
		t.Errorf("ID: expected apple:song123, got %s", track.ID)
	}
	if track.Title != "Test Song" {
		t.Errorf("Title: expected Test Song, got %s", track.Title)
	}
	if track.ISRC != "USABC123" {
		t.Errorf("ISRC: expected USABC123, got %s", track.ISRC)
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

// ─── GetAlbum ────────────────────────────────────────────────────

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/albums/album789") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"data": []map[string]interface{}{
				{
					"id": "album789",
					"attributes": map[string]interface{}{
						"name":       "Test Album",
						"artistName": "Test Artist",
						"releaseDate": "2024-01-01",
						"trackCount": 12,
						"artwork": map[string]interface{}{
							"url": "https://artwork.cdn/apple/{w}x{h}.jpg",
						},
					},
				},
			},
		}), nil
	})
	album, err := c.GetAlbum("album789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "apple:album789" {
		t.Errorf("ID: expected apple:album789, got %s", album.ID)
	}
	if album.Title != "Test Album" {
		t.Errorf("Title: expected Test Album, got %s", album.Title)
	}
	if album.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", album.Artist)
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

// ─── GetArtist ───────────────────────────────────────────────────

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/artists/artist456") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"data": []map[string]interface{}{
				{
					"id": "artist456",
					"attributes": map[string]interface{}{
						"name": "Test Artist",
						"artwork": map[string]interface{}{
							"url": "https://artwork.cdn/apple/{w}x{h}.jpg",
						},
					},
				},
			},
		}), nil
	})
	artist, err := c.GetArtist("artist456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "apple:artist456" {
		t.Errorf("ID: expected apple:artist456, got %s", artist.ID)
	}
	if artist.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", artist.Name)
	}
}

// ─── GetTrackByISRC ──────────────────────────────────────────────

func TestGetTrackByISRC_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"songs": map[string]interface{}{
					"data": []map[string]interface{}{
						{
							"id": "song123",
							"attributes": map[string]interface{}{
								"name":             "Test Song",
								"artistName":       "Test Artist",
								"albumName":        "Test Album",
								"durationInMillis": 200000,
								"isrc":             "USABC123",
								"artwork": map[string]interface{}{
									"url": "https://artwork.cdn/apple/{w}x{h}.jpg",
								},
							},
						},
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

// ─── GetStreamURL ────────────────────────────────────────────────

func TestGetStreamURL_ReturnsError(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		t.Error("GetStreamURL should not make HTTP requests (DRM)")
		return okJSON(map[string]interface{}{"data": []map[string]interface{}{}}), nil
	})
	_, err := c.GetStreamURL("song123", "lossless")
	if err == nil {
		t.Fatal("expected error for DRM-protected stream")
	}
	if !strings.Contains(err.Error(), "FairPlay") {
		t.Errorf("expected FairPlay error, got: %v", err)
	}
}

// ─── Request verification ────────────────────────────────────────

func TestAppleRequestHeaders(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"songs": map[string]interface{}{"data": []map[string]interface{}{}},
			},
		}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("Authorization") != "Bearer test-token" {
		t.Errorf("Authorization header: expected Bearer test-token, got %s", captured.Header.Get("Authorization"))
	}
}
