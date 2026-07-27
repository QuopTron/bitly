package soundcloud

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
	return NewClient(&http.Client{Transport: &mockTransport{roundTrip: handler}}, "test-client-id")
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
		Body:       io.NopCloser(strings.NewReader(`{"error":"`+msg+`"}`)),
		Header:     make(http.Header),
	}
}

// ─── Client ID check ─────────────────────────────────────────────

func TestRequiresClientID(t *testing.T) {
	c := NewClient(nil, "")
	_, err := c.SearchTracks("test", 5)
	if err == nil || !strings.Contains(err.Error(), "client_id not set") {
		t.Errorf("expected client_id error, got: %v", err)
	}
	_, err2 := c.SearchAlbums("test", 5)
	if err2 == nil || !strings.Contains(err2.Error(), "client_id not set") {
		t.Errorf("expected client_id error, got: %v", err2)
	}
	_, err3 := c.GetTrack("1")
	if err3 == nil || !strings.Contains(err3.Error(), "client_id not set") {
		t.Errorf("expected client_id error, got: %v", err3)
	}
}

// ─── SearchTracks ────────────────────────────────────────────────

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/tracks") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id": 123, "title": "Test Track", "duration": 200000,
					"genre": "Pop", "artwork_url": "https://artwork.sc/1.jpg",
					"user": map[string]interface{}{
						"id": 456, "username": "Test Artist",
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
	if r.ID != "sc:123" {
		t.Errorf("ID: expected sc:123, got %s", r.ID)
	}
	if r.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.ArtistID != "sc:456" {
		t.Errorf("ArtistID: expected sc:456, got %s", r.ArtistID)
	}
	if r.Duration != 200000 {
		t.Errorf("Duration: expected 200000, got %d", r.Duration)
	}
	if r.CoverURL != "https://artwork.sc/1.jpg" {
		t.Errorf("CoverURL: expected https://artwork.sc/1.jpg, got %s", r.CoverURL)
	}
	if r.Provider != "soundcloud" {
		t.Errorf("Provider: expected soundcloud, got %s", r.Provider)
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"collection": []map[string]interface{}{}}), nil
	})
	results, err := c.SearchTracks("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

func TestSearchTracks_HTTPError(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return errJSON(429, "rate limited"), nil
	})
	_, err := c.SearchTracks("test", 5)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

// ─── SearchAlbums ────────────────────────────────────────────────

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/playlists") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id": 789, "title": "Test Album", "artwork_url": "https://artwork.sc/2.jpg",
					"track_count": 10, "is_album": true,
					"user": map[string]interface{}{
						"id": 456, "username": "Test Artist",
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
	if r.ID != "sc:789" {
		t.Errorf("ID: expected sc:789, got %s", r.ID)
	}
	if r.Title != "Test Album" {
		t.Errorf("Title: expected Test Album, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.TrackCount != 10 {
		t.Errorf("TrackCount: expected 10, got %d", r.TrackCount)
	}
}

func TestSearchAlbums_FiltersNonAlbums(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id": 111, "title": "A Playlist", "is_album": false,
					"track_count": 5, "artwork_url": "",
					"user": map[string]interface{}{"id": 1, "username": "User"},
				},
				{
					"id": 222, "title": "Real Album", "is_album": true,
					"track_count": 12, "artwork_url": "",
					"user": map[string]interface{}{"id": 2, "username": "Artist"},
				},
			},
		}), nil
	})
	results, err := c.SearchAlbums("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 1 {
		t.Errorf("expected 1 result (album), got %d", len(results))
	}
}

func TestSearchAlbums_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"collection": []map[string]interface{}{}}), nil
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
		if !strings.Contains(req.URL.String(), "/search/users") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id": 456, "username": "Test Artist", "avatar_url": "https://avatar.sc/1.jpg",
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
	if r.ID != "sc:456" {
		t.Errorf("ID: expected sc:456, got %s", r.ID)
	}
	if r.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", r.Name)
	}
	if r.PictureURL != "https://avatar.sc/1.jpg" {
		t.Errorf("PictureURL: expected https://avatar.sc/1.jpg, got %s", r.PictureURL)
	}
}

// ─── GetTrack ────────────────────────────────────────────────────

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/tracks/123") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id": 123, "title": "Test Track", "duration": 200000,
			"genre": "Pop", "artwork_url": "https://artwork.sc/1.jpg",
			"user": map[string]interface{}{
				"id": 456, "username": "Test Artist",
			},
		}), nil
	})
	track, err := c.GetTrack("123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "sc:123" {
		t.Errorf("ID: expected sc:123, got %s", track.ID)
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

func TestGetTrack_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return errJSON(404, "not found"), nil
	})
	_, err := c.GetTrack("999")
	if err == nil {
		t.Fatal("expected error for missing track")
	}
}

// ─── GetAlbum ────────────────────────────────────────────────────

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/playlists/789") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id": 789, "title": "Test Album", "artwork_url": "https://artwork.sc/2.jpg",
			"track_count": 10, "description": "An album",
			"user": map[string]interface{}{
				"id": 456, "username": "Test Artist",
			},
		}), nil
	})
	album, err := c.GetAlbum("789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "sc:789" {
		t.Errorf("ID: expected sc:789, got %s", album.ID)
	}
	if album.Title != "Test Album" {
		t.Errorf("Title: expected Test Album, got %s", album.Title)
	}
	if album.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", album.Artist)
	}
	if album.TrackCount != 10 {
		t.Errorf("TrackCount: expected 10, got %d", album.TrackCount)
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

// ─── GetArtist ───────────────────────────────────────────────────

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/users/456") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id": 456, "username": "Test Artist", "avatar_url": "https://avatar.sc/1.jpg",
			"description": "A musician", "followers_count": 5000, "track_count": 50,
		}), nil
	})
	artist, err := c.GetArtist("456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "sc:456" {
		t.Errorf("ID: expected sc:456, got %s", artist.ID)
	}
	if artist.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", artist.Name)
	}
	if artist.PictureURL != "https://avatar.sc/1.jpg" {
		t.Errorf("PictureURL: expected https://avatar.sc/1.jpg, got %s", artist.PictureURL)
	}
}

// ─── GetTrackByISRC ──────────────────────────────────────────────

func TestGetTrackByISRC_ReturnsError(t *testing.T) {
	c := mockClient(nil)
	_, err := c.GetTrackByISRC("USABC123")
	if err == nil {
		t.Fatal("expected error for ISRC lookup")
	}
	if !strings.Contains(err.Error(), "ISRC") {
		t.Errorf("expected ISRC-related error, got: %v", err)
	}
}

// ─── GetStreamURL ────────────────────────────────────────────────

func TestGetStreamURL_Success(t *testing.T) {
	calls := 0
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		calls++
		if strings.Contains(req.URL.String(), "/tracks/123") {
			return okJSON(map[string]interface{}{
				"media": map[string]interface{}{
					"transcodings": []map[string]interface{}{
						{
							"url": "https://api-v2.soundcloud.com/tracks/123/stream",
							"format": map[string]interface{}{
								"protocol": "progressive",
							},
						},
					},
				},
			}), nil
		}
		return nil, nil
	})
	url, err := c.GetStreamURL("123", "")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(url, "client_id=test-client-id") {
		t.Errorf("URL should contain client_id, got: %s", url)
	}
	if !strings.HasPrefix(url, "https://api-v2.soundcloud.com/tracks/123/stream?client_id=") {
		t.Errorf("unexpected URL: %s", url)
	}
	if calls != 1 {
		t.Errorf("expected 1 HTTP call, got %d", calls)
	}
}

func TestGetStreamURL_FallsBackToHLS(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"media": map[string]interface{}{
				"transcodings": []map[string]interface{}{
					{
						"url": "https://api-v2.soundcloud.com/tracks/123/hls",
						"format": map[string]interface{}{
							"protocol": "hls",
						},
					},
				},
			},
		}), nil
	})
	url, err := c.GetStreamURL("123", "")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(url, "client_id=test-client-id") {
		t.Errorf("URL should contain client_id, got: %s", url)
	}
}

func TestGetStreamURL_NoTranscodings(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"media": map[string]interface{}{
				"transcodings": []map[string]interface{}{},
			},
		}), nil
	})
	_, err := c.GetStreamURL("123", "")
	if err == nil {
		t.Fatal("expected error for no transcodings")
	}
}

func TestGetStreamURL_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return errJSON(404, "not found"), nil
	})
	_, err := c.GetStreamURL("999", "")
	if err == nil {
		t.Fatal("expected error for missing track")
	}
}

// ─── Request verification ────────────────────────────────────────

func TestSoundCloudRequestContainsClientID(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(map[string]interface{}{"collection": []map[string]interface{}{}}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	q := captured.URL.Query()
	if q.Get("client_id") != "test-client-id" {
		t.Errorf("client_id param: expected test-client-id, got %s", q.Get("client_id"))
	}
	if q.Get("q") != "test" {
		t.Errorf("q param: expected test, got %s", q.Get("q"))
	}
}
