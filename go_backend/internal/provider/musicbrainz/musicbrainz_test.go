package musicbrainz

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
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
		http:  &http.Client{Transport: &mockTransport{roundTrip: handler}},
		app:   "BitlyTest/1.0",
		limit: httpclient.NewRateLimiter(httpclient.RateLimitConfig{RequestsPerSecond: 10000, Burst: 10000}),
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

// ─── SearchTracks ────────────────────────────────────────────────

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/recording") {
			t.Errorf("expected /recording, got: %s", req.URL.Path)
		}
		if !strings.Contains(req.URL.RawQuery, "fmt=json") {
			t.Errorf("expected fmt=json, got: %s", req.URL.RawQuery)
		}
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{
				{
					"id":     "abc-123-def",
					"title":  "Test Song",
					"length": 240000,
					"isrcs": []map[string]interface{}{
						{"id": "USABC1234567"},
					},
					"artist-credit": []map[string]interface{}{
						{
							"name": "Test Artist",
							"artist": map[string]interface{}{
								"id": "artist-456",
							},
						},
					},
					"releases": []map[string]interface{}{
						{
							"id":    "release-789",
							"title": "Test Album",
						},
					},
				},
			},
		}), nil
	})
	results, err := c.SearchTracks("Test Song", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	r := results[0]
	if r.ID != "mb:abc-123-def" {
		t.Errorf("ID: expected mb:abc-123-def, got %s", r.ID)
	}
	if r.Title != "Test Song" {
		t.Errorf("Title: expected Test Song, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.ISRC != "USABC1234567" {
		t.Errorf("ISRC: expected USABC1234567, got %s", r.ISRC)
	}
	if r.Album != "Test Album" {
		t.Errorf("Album: expected Test Album, got %s", r.Album)
	}
	if r.Provider != "musicbrainz" {
		t.Errorf("Provider: expected musicbrainz, got %s", r.Provider)
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"recordings": []map[string]interface{}{}}), nil
	})
	results, err := c.SearchTracks("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

func TestSearchTracks_NoArtistCredit(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{
				{
					"id":     "abc-123",
					"title":  "Unknown Artist Song",
					"length": 200000,
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
	if r.Artist != "" {
		t.Errorf("Artist should be empty, got: %s", r.Artist)
	}
	if r.Album != "" {
		t.Errorf("Album should be empty, got: %s", r.Album)
	}
}

// ─── SearchAlbums ────────────────────────────────────────────────

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/release") {
			t.Errorf("expected /release, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"releases": []map[string]interface{}{
				{
					"id":    "release-789",
					"title": "Test Album",
					"date":  "2024-01-15",
					"track-count": 12,
					"artist-credit": []map[string]interface{}{
						{
							"name": "Test Artist",
							"artist": map[string]interface{}{
								"id": "artist-456",
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
	if r.ID != "mb:release-789" {
		t.Errorf("ID: expected mb:release-789, got %s", r.ID)
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
	if r.CoverURL != "https://coverartarchive.org/release/release-789/front-250.jpg" {
		t.Errorf("CoverURL unexpected: %s", r.CoverURL)
	}
}

func TestSearchAlbums_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"releases": []map[string]interface{}{}}), nil
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
		if !strings.Contains(req.URL.String(), "/artist") {
			t.Errorf("expected /artist, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"artists": []map[string]interface{}{
				{
					"id":   "artist-456",
					"name": "Test Artist",
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
	if r.ID != "mb:artist-456" {
		t.Errorf("ID: expected mb:artist-456, got %s", r.ID)
	}
	if r.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", r.Name)
	}
	if r.Provider != "musicbrainz" {
		t.Errorf("Provider: expected musicbrainz, got %s", r.Provider)
	}
}

// ─── SearchPlaylists ─────────────────────────────────────────────

func TestSearchPlaylists_ReturnsNil(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		t.Error("SearchPlaylists should not make HTTP requests (not supported)")
		return nil, nil
	})
	results, err := c.SearchPlaylists("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if results != nil {
		t.Errorf("expected nil results, got %v", results)
	}
}

// ─── GetTrack ────────────────────────────────────────────────────

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{
				{
					"id":     "rec-123",
					"title":  "Direct Track",
					"length": 200000,
					"artist-credit": []map[string]interface{}{
						{
							"name": "Some Artist",
							"artist": map[string]interface{}{"id": "art-1"},
						},
					},
				},
			},
		}), nil
	})
	track, err := c.GetTrack("rec-123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "mb:rec-123" {
		t.Errorf("ID: expected mb:rec-123, got %s", track.ID)
	}
	if track.Title != "Direct Track" {
		t.Errorf("Title: expected Direct Track, got %s", track.Title)
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

// ─── GetTrackByISRC ──────────────────────────────────────────────

func TestGetTrackByISRC_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{
				{
					"id":     "rec-isrc-123",
					"title":  "ISRC Track",
					"length": 180000,
					"isrcs":  []map[string]interface{}{{"id": "USABC1234567"}},
				},
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

// ─── GetAlbum ────────────────────────────────────────────────────

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/release/release-789") {
			t.Errorf("expected /release/release-789, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id":    "release-789",
			"title": "Direct Album",
			"date":  "2024-06-01",
			"track-count": 10,
			"artist-credit": []map[string]interface{}{
				{
					"name": "Album Artist",
					"artist": map[string]interface{}{"id": "art-2"},
				},
			},
		}), nil
	})
	album, err := c.GetAlbum("release-789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "mb:release-789" {
		t.Errorf("ID: expected mb:release-789, got %s", album.ID)
	}
	if album.Title != "Direct Album" {
		t.Errorf("Title: expected Direct Album, got %s", album.Title)
	}
	if album.Artist != "Album Artist" {
		t.Errorf("Artist: expected Album Artist, got %s", album.Artist)
	}
	if album.ReleaseDate != "2024-06-01" {
		t.Errorf("ReleaseDate: expected 2024-06-01, got %s", album.ReleaseDate)
	}
	if album.TrackCount != 10 {
		t.Errorf("TrackCount: expected 10, got %d", album.TrackCount)
	}
}

// ─── GetArtist ───────────────────────────────────────────────────

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/artist/artist-456") {
			t.Errorf("expected /artist/artist-456, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"id":   "artist-456",
			"name": "Direct Artist",
		}), nil
	})
	artist, err := c.GetArtist("artist-456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "mb:artist-456" {
		t.Errorf("ID: expected mb:artist-456, got %s", artist.ID)
	}
	if artist.Name != "Direct Artist" {
		t.Errorf("Name: expected Direct Artist, got %s", artist.Name)
	}
}

// ─── GetStreamURL ────────────────────────────────────────────────

func TestGetStreamURL_ReturnsError(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		t.Error("GetStreamURL should not make HTTP requests (metadata only)")
		return nil, nil
	})
	_, err := c.GetStreamURL("rec-123", "flac")
	if err == nil {
		t.Fatal("expected error for metadata-only provider")
	}
	if !strings.Contains(err.Error(), "no stream URLs") {
		t.Errorf("expected 'no stream URLs' error, got: %v", err)
	}
}

// ─── coverArtURL ─────────────────────────────────────────────────

func TestCoverArtURL_WithReleaseID(t *testing.T) {
	url := coverArtURL("release-abc")
	expected := "https://coverartarchive.org/release/release-abc/front-250.jpg"
	if url != expected {
		t.Errorf("expected %s, got %s", expected, url)
	}
}

func TestCoverArtURL_EmptyReleaseID(t *testing.T) {
	url := coverArtURL("")
	if url != "" {
		t.Errorf("expected empty string, got %s", url)
	}
}

// ─── Request verification ────────────────────────────────────────

func TestMusicBrainzRequestHeaders(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{},
		}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("User-Agent") != "BitlyTest/1.0" {
		t.Errorf("User-Agent: expected BitlyTest/1.0, got %s", captured.Header.Get("User-Agent"))
	}
	if captured.Header.Get("Accept") != "application/json" {
		t.Errorf("Accept: expected application/json, got %s", captured.Header.Get("Accept"))
	}
}
