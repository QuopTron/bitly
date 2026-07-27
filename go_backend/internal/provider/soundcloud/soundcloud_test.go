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
	return &Client{
		http:     &http.Client{Transport: &mockTransport{roundTrip: handler}},
		clientID: "test-client-id",
	}
}

func okJSON(body interface{}) *http.Response {
	b, _ := json.Marshal(body)
	return &http.Response{
		StatusCode: http.StatusOK,
		Body:       io.NopCloser(strings.NewReader(string(b))),
		Header:     make(http.Header),
	}
}

func errSCResponse(status int) *http.Response {
	return &http.Response{
		StatusCode: status,
		Body:       io.NopCloser(strings.NewReader(`{"error":"not found"}`)),
		Header:     make(http.Header),
	}
}

// ─── SearchTracks ────────────────────────────────────────────────

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/tracks") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		if !strings.Contains(req.URL.RawQuery, "client_id=test-client-id") {
			t.Errorf("expected client_id param, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id":          123456,
					"title":       "Test Track",
					"duration":    240000,
					"genre":       "Pop",
					"user": map[string]interface{}{
						"id":       789,
						"username": "Test Artist",
					},
					"artwork_url": "https://i1.sndcdn.com/artworks-test-t500x500.jpg",
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
	if r.ID != "sc:123456" {
		t.Errorf("ID: expected sc:123456, got %s", r.ID)
	}
	if r.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.Duration != 240000 {
		t.Errorf("Duration: expected 240000, got %d", r.Duration)
	}
	if !strings.Contains(r.CoverURL, "artworks-test") {
		t.Errorf("CoverURL unexpected: %s", r.CoverURL)
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

func TestSearchTracks_NoClientID(t *testing.T) {
	c := NewClient(nil, "")
	_, err := c.SearchTracks("test", 5)
	if err == nil || !strings.Contains(err.Error(), "client_id not set") {
		t.Errorf("expected client_id error, got: %v", err)
	}
}

func TestSearchTracks_HTTPError(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return errSCResponse(500), nil
	})
	_, err := c.SearchTracks("test", 5)
	if err == nil {
		t.Fatal("expected HTTP error")
	}
}

// ─── SearchAlbums ────────────────────────────────────────────────

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/playlists") {
			t.Errorf("expected /search/playlists, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id":          456,
					"title":       "Test Album",
					"artwork_url": "https://i1.sndcdn.com/artworks-album-t500x500.jpg",
					"track_count": 12,
					"is_album":    true,
					"user": map[string]interface{}{
						"id":       789,
						"username": "Test Artist",
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
	if r.ID != "sc:456" {
		t.Errorf("ID: expected sc:456, got %s", r.ID)
	}
	if r.Title != "Test Album" {
		t.Errorf("Title: expected Test Album, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.TrackCount != 12 {
		t.Errorf("TrackCount: expected 12, got %d", r.TrackCount)
	}
}

func TestSearchAlbums_FiltersNonAlbums(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id":          456,
					"title":       "A Playlist",
					"artwork_url": "",
					"track_count": 50,
					"is_album":    false, // Not an album, should be filtered
					"user": map[string]interface{}{
						"id":       789,
						"username": "Test User",
					},
				},
			},
		}), nil
	})
	results, err := c.SearchAlbums("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 (is_album=false), got %d", len(results))
	}
}

// ─── SearchPlaylists ─────────────────────────────────────────────

func TestSearchPlaylists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/playlists") {
			t.Errorf("expected /search/playlists, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id":          456,
					"title":       "Test Playlist",
					"description": "A great playlist",
					"artwork_url": "https://i1.sndcdn.com/artworks-pl-t500x500.jpg",
					"track_count": 25,
					"user": map[string]interface{}{
						"id":       789,
						"username": "Test Curator",
					},
				},
			},
		}), nil
	})
	results, err := c.SearchPlaylists("test", 5)
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
	if r.Title != "Test Playlist" {
		t.Errorf("Title: expected Test Playlist, got %s", r.Title)
	}
	if r.Creator != "Test Curator" {
		t.Errorf("Creator: expected Test Curator, got %s", r.Creator)
	}
	if r.TrackCount != 25 {
		t.Errorf("TrackCount: expected 25, got %d", r.TrackCount)
	}
	if r.Description != "A great playlist" {
		t.Errorf("Description: expected 'A great playlist', got %s", r.Description)
	}
}

// ─── SearchArtists ───────────────────────────────────────────────

func TestSearchArtists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/users") {
			t.Errorf("expected /search/users, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id":         789,
					"username":   "Test Artist",
					"avatar_url": "https://i1.sndcdn.com/avatars-test-t500x500.jpg",
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
	if r.ID != "sc:789" {
		t.Errorf("ID: expected sc:789, got %s", r.ID)
	}
	if r.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", r.Name)
	}
	if !strings.Contains(r.PictureURL, "avatars-test") {
		t.Errorf("PictureURL unexpected: %s", r.PictureURL)
	}
}

// ─── GetTrack ────────────────────────────────────────────────────

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/tracks/123456") {
			t.Errorf("expected /tracks/123456, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id":          123456,
			"title":       "Test Track",
			"duration":    240000,
			"genre":       "Pop",
			"artwork_url": "https://i1.sndcdn.com/artworks-track-t500x500.jpg",
			"stream_url":  "https://api.soundcloud.com/tracks/123456/stream",
			"user": map[string]interface{}{
				"id":       789,
				"username": "Test Artist",
			},
			"media": map[string]interface{}{
				"transcodings": []map[string]interface{}{
					{
						"url": "https://api.soundcloud.com/tracks/123456/transcodings/abc",
						"format": map[string]interface{}{
							"protocol": "progressive",
						},
					},
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
	if track.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", track.Artist)
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

// ─── GetTrackByISRC ──────────────────────────────────────────────

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

// ─── GetAlbum ────────────────────────────────────────────────────

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/playlists/456") {
			t.Errorf("expected /playlists/456, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id":          456,
			"title":       "Test Album",
			"artwork_url": "https://i1.sndcdn.com/artworks-album-t500x500.jpg",
			"track_count": 12,
			"description": "An album description",
			"user": map[string]interface{}{
				"id":       789,
				"username": "Test Artist",
			},
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

// ─── GetArtist ───────────────────────────────────────────────────

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/users/789") {
			t.Errorf("expected /users/789, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id":             789,
			"username":       "Test Artist",
			"avatar_url":     "https://i1.sndcdn.com/avatars-user-t500x500.jpg",
			"description":    "A great artist",
			"followers_count": 1500,
			"track_count":    25,
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

// ─── GetStreamURL ────────────────────────────────────────────────

func TestGetStreamURL_ProgressivePreferred(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"media": map[string]interface{}{
				"transcodings": []map[string]interface{}{
					{
						"url": "https://api.soundcloud.com/tracks/123/hls",
						"format": map[string]interface{}{
							"protocol": "hls",
						},
					},
					{
						"url": "https://api.soundcloud.com/tracks/123/progressive",
						"format": map[string]interface{}{
							"protocol": "progressive",
						},
					},
				},
			},
		}), nil
	})
	url, err := c.GetStreamURL("123", "mp3")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(url, "progressive") {
		t.Errorf("expected progressive URL, got: %s", url)
	}
	if !strings.Contains(url, "client_id=test-client-id") {
		t.Errorf("expected client_id param, got: %s", url)
	}
}

func TestGetStreamURL_FallbackHLS(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"media": map[string]interface{}{
				"transcodings": []map[string]interface{}{
					{
						"url": "https://api.soundcloud.com/tracks/123/hls-only",
						"format": map[string]interface{}{
							"protocol": "hls",
						},
					},
				},
			},
		}), nil
	})
	url, err := c.GetStreamURL("123", "mp3")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(url, "hls-only") {
		t.Errorf("expected HLS fallback URL, got: %s", url)
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
	_, err := c.GetStreamURL("123", "mp3")
	if err == nil {
		t.Fatal("expected error for no transcodings")
	}
}

// ─── Request verification ────────────────────────────────────────

func TestSoundCloudRequestHeaders(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(map[string]interface{}{"collection": []map[string]interface{}{}}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("Accept") != "application/json" {
		t.Errorf("Accept header: expected application/json, got %s", captured.Header.Get("Accept"))
	}
	ua := captured.Header.Get("User-Agent")
	if ua == "" {
		t.Error("User-Agent header should not be empty")
	}
	if !strings.Contains(captured.URL.RawQuery, "client_id=test-client-id") {
		t.Errorf("expected client_id in query, got: %s", captured.URL.RawQuery)
	}
}
