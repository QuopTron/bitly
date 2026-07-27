package spotify

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

// withToken wraps a handler to auto-respond to OAuth token requests.
func withToken(handler func(req *http.Request) (*http.Response, error)) func(req *http.Request) (*http.Response, error) {
	return func(req *http.Request) (*http.Response, error) {
		if strings.Contains(req.URL.String(), "/api/token") {
			return okJSON(map[string]interface{}{
				"access_token": "mock-token",
				"token_type":   "Bearer",
				"expires_in":   3600,
			}), nil
		}
		return handler(req)
	}
}

func mockClient(handler func(req *http.Request) (*http.Response, error)) *Client {
	return NewClient(
		&http.Client{Transport: &mockTransport{roundTrip: withToken(handler)}},
		"test-id", "test-secret",
	)
}

func okJSON(body interface{}) *http.Response {
	b, _ := json.Marshal(body)
	return &http.Response{
		StatusCode: http.StatusOK,
		Body:       io.NopCloser(strings.NewReader(string(b))),
		Header:     make(http.Header),
	}
}

// ─── SearchTracks ────────────────────────────────────────────────

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "type=track") {
			t.Errorf("expected type=track, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"tracks": map[string]interface{}{
				"items": []map[string]interface{}{
					{
						"id": "track123", "name": "Test Track",
						"duration_ms": 200000, "explicit": false,
						"artists": []map[string]interface{}{
							{"id": "artist456", "name": "Test Artist"},
						},
						"album": map[string]interface{}{
							"id": "album789", "name": "Test Album",
							"images": []map[string]interface{}{
								{"url": "https://image.url/1"},
							},
						},
						"external_ids": map[string]interface{}{
							"isrc": "USABC123",
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
	if r.ID != "spotify:track123" {
		t.Errorf("ID: expected spotify:track123, got %s", r.ID)
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
	if r.Duration != 200000 {
		t.Errorf("Duration: expected 200000, got %d", r.Duration)
	}
	if r.ISRC != "USABC123" {
		t.Errorf("ISRC: expected USABC123, got %s", r.ISRC)
	}
	if r.CoverURL != "https://image.url/1" {
		t.Errorf("CoverURL: expected https://image.url/1, got %s", r.CoverURL)
	}
	if r.Provider != "spotify" {
		t.Errorf("Provider: expected spotify, got %s", r.Provider)
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"tracks": map[string]interface{}{"items": []map[string]interface{}{}},
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
		if !strings.Contains(req.URL.String(), "type=album") {
			t.Errorf("expected type=album, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"albums": map[string]interface{}{
				"items": []map[string]interface{}{
					{
						"id": "album789", "name": "Test Album",
						"release_date": "2024-01-15", "total_tracks": 12,
						"images": []map[string]interface{}{
							{"url": "https://image.url/album"},
						},
						"artists": []map[string]interface{}{
							{"id": "artist456", "name": "Test Artist"},
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
	if r.ID != "spotify:album789" {
		t.Errorf("ID: expected spotify:album789, got %s", r.ID)
	}
	if r.Title != "Test Album" {
		t.Errorf("Title: expected Test Album, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.ReleaseDate != "2024-01-15" {
		t.Errorf("ReleaseDate: expected 2024-01-15, got %s", r.ReleaseDate)
	}
	if r.TrackCount != 12 {
		t.Errorf("TrackCount: expected 12, got %d", r.TrackCount)
	}
	if r.CoverURL != "https://image.url/album" {
		t.Errorf("CoverURL: expected https://image.url/album, got %s", r.CoverURL)
	}
}

func TestSearchAlbums_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"albums": map[string]interface{}{"items": []map[string]interface{}{}},
		}), nil
	})
	results, err := c.SearchAlbums("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

// ─── SearchArtists ───────────────────────────────────────────────

func TestSearchArtists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "type=artist") {
			t.Errorf("expected type=artist, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"artists": map[string]interface{}{
				"items": []map[string]interface{}{
					{
						"id": "artist456", "name": "Test Artist",
						"images": []map[string]interface{}{
							{"url": "https://image.url/artist"},
						},
						"followers": map[string]interface{}{
							"total": 5000,
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
	if r.ID != "spotify:artist456" {
		t.Errorf("ID: expected spotify:artist456, got %s", r.ID)
	}
	if r.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", r.Name)
	}
	if r.PictureURL != "https://image.url/artist" {
		t.Errorf("PictureURL: expected https://image.url/artist, got %s", r.PictureURL)
	}
	if r.Fans != 5000 {
		t.Errorf("Fans: expected 5000, got %d", r.Fans)
	}
}

func TestSearchArtists_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"artists": map[string]interface{}{"items": []map[string]interface{}{}},
		}), nil
	})
	results, err := c.SearchArtists("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

// ─── GetTrack ────────────────────────────────────────────────────

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/tracks/track123") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id": "track123", "name": "Test Track",
			"duration_ms": 200000, "explicit": false,
			"artists": []map[string]interface{}{
				{"id": "artist456", "name": "Test Artist"},
			},
			"album": map[string]interface{}{
				"id": "album789", "name": "Test Album",
				"images": []map[string]interface{}{
					{"url": "https://image.url/1"},
				},
			},
			"external_ids": map[string]interface{}{
				"isrc": "USABC123",
			},
		}), nil
	})
	track, err := c.GetTrack("track123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "spotify:track123" {
		t.Errorf("ID: expected spotify:track123, got %s", track.ID)
	}
	if track.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", track.Title)
	}
	if track.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", track.Artist)
	}
	if track.Duration != 200000 {
		t.Errorf("Duration: expected 200000, got %d", track.Duration)
	}
}

// ─── GetAlbum ────────────────────────────────────────────────────

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/albums/album789") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id": "album789", "name": "Test Album",
			"release_date": "2024-01-15", "total_tracks": 12,
			"images": []map[string]interface{}{
				{"url": "https://image.url/album"},
			},
			"artists": []map[string]interface{}{
				{"id": "artist456", "name": "Test Artist"},
			},
		}), nil
	})
	album, err := c.GetAlbum("album789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "spotify:album789" {
		t.Errorf("ID: expected spotify:album789, got %s", album.ID)
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
	if album.ReleaseDate != "2024-01-15" {
		t.Errorf("ReleaseDate: expected 2024-01-15, got %s", album.ReleaseDate)
	}
}

// ─── GetArtist ───────────────────────────────────────────────────

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/artists/artist456") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id": "artist456", "name": "Test Artist",
			"images": []map[string]interface{}{
				{"url": "https://image.url/artist"},
			},
		}), nil
	})
	artist, err := c.GetArtist("artist456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "spotify:artist456" {
		t.Errorf("ID: expected spotify:artist456, got %s", artist.ID)
	}
	if artist.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", artist.Name)
	}
	if artist.PictureURL != "https://image.url/artist" {
		t.Errorf("PictureURL: expected https://image.url/artist, got %s", artist.PictureURL)
	}
}

// ─── GetTrackByISRC ──────────────────────────────────────────────

func TestGetTrackByISRC_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"tracks": map[string]interface{}{
				"items": []map[string]interface{}{
					{
						"id": "track123", "name": "Test Track",
						"duration_ms": 200000,
						"artists":     []map[string]interface{}{},
						"album": map[string]interface{}{
							"id": "album789", "name": "Test Album",
						},
						"external_ids": map[string]interface{}{
							"isrc": "USABC123",
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
			"tracks": map[string]interface{}{"items": []map[string]interface{}{}},
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
		t.Error("GetStreamURL should not make HTTP requests")
		return okJSON(map[string]interface{}{}), nil
	})
	_, err := c.GetStreamURL("track123", "lossless")
	if err == nil {
		t.Fatal("expected error for stream URL")
	}
	if !strings.Contains(err.Error(), "does not provide stream URLs") {
		t.Errorf("expected stream URL error, got: %v", err)
	}
}

// ─── Token refresh ───────────────────────────────────────────────

func TestTokenRefreshOn401(t *testing.T) {
	callCount := 0
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		callCount++
		if callCount == 1 {
			// First API call returns 401 — triggers token refresh
			return &http.Response{
				StatusCode: 401,
				Body:       io.NopCloser(strings.NewReader(`{"error":"unauthorized"}`)),
				Header:     make(http.Header),
			}, nil
		}
		// Retry succeeds
		return okJSON(map[string]interface{}{
			"tracks": map[string]interface{}{"items": []map[string]interface{}{}},
		}), nil
	})
	_, err := c.SearchTracks("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if callCount != 2 {
		t.Errorf("expected 2 API calls (1st fails, 2nd succeeds), got %d", callCount)
	}
}

// ─── HTTP error ──────────────────────────────────────────────────

func TestSearchTracks_HTTPError(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return &http.Response{
			StatusCode: 429,
			Body:       io.NopCloser(strings.NewReader(`{"error":"rate limited"}`)),
			Header:     make(http.Header),
		}, nil
	})
	_, err := c.SearchTracks("test", 5)
	if err == nil {
		t.Fatal("expected error for 429 response")
	}
	if !strings.Contains(err.Error(), "429") {
		t.Errorf("expected 429 in error message, got: %v", err)
	}
}

// ─── Request verification ────────────────────────────────────────

func TestAuthorizationHeader(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(map[string]interface{}{
			"tracks": map[string]interface{}{"items": []map[string]interface{}{}},
		}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("Authorization") != "Bearer mock-token" {
		t.Errorf("Authorization: expected Bearer mock-token, got %s", captured.Header.Get("Authorization"))
	}
}
