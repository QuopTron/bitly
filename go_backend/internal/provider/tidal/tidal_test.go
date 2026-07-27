package tidal

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
	return NewClient(&http.Client{Transport: &mockTransport{roundTrip: handler}}, "", "")
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

// ─── SearchTracks ────────────────────────────────────────────────

func TestSearchTracks_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/tracks") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(SearchResponse{
			Items: []Track{{
				ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
				Artist: ArtistRef{ID: 456, Name: "Test Artist"},
				Album:  AlbumRef{ID: 789, Title: "Test Album", Cover: "https://cover.url/1"},
			}},
			TotalCount: 1,
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
	if r.ID != "tidal:123" {
		t.Errorf("ID: expected tidal:123, got %s", r.ID)
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
	if r.Duration != 200 {
		t.Errorf("Duration: expected 200, got %d", r.Duration)
	}
	if r.ISRC != "USABC123" {
		t.Errorf("ISRC: expected USABC123, got %s", r.ISRC)
	}
	if r.CoverURL != "https://cover.url/1" {
		t.Errorf("CoverURL: expected https://cover.url/1, got %s", r.CoverURL)
	}
	if r.Provider != "tidal" {
		t.Errorf("Provider: expected tidal, got %s", r.Provider)
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{Items: []Track{}, TotalCount: 0}), nil
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
		return errJSON(401, "unauthorized"), nil
	})
	_, err := c.SearchTracks("test", 5)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func TestSearchTracks_LimitClamping(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{Items: []Track{}, TotalCount: 0}), nil
	})
	// limit=0 should clamp to 25
	_, _ = c.SearchTracks("test", 0)
	// limit=200 should clamp to 100
	_, _ = c.SearchTracks("test", 200)
}

// ─── SearchAlbums ────────────────────────────────────────────────

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/albums") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(AlbumSearchResponse{
			Items: []Album{{
				ID: 789, Title: "Test Album", ReleaseDate: "2024-01-01",
				Cover: "https://cover.url/2", TrackCount: 12,
				Artist: ArtistRef{ID: 456, Name: "Test Artist"},
			}},
			TotalCount: 1,
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
	if r.ID != "tidal:789" {
		t.Errorf("ID: expected tidal:789, got %s", r.ID)
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
}

func TestSearchAlbums_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(AlbumSearchResponse{Items: []Album{}, TotalCount: 0}), nil
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
		if !strings.Contains(req.URL.String(), "/search/artists") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(ArtistSearchResponse{
			Items: []Artist{{
				ID: 456, Name: "Test Artist", PictureURL: "https://pic.url/1",
			}},
			TotalCount: 1,
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
	if r.ID != "tidal:456" {
		t.Errorf("ID: expected tidal:456, got %s", r.ID)
	}
	if r.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", r.Name)
	}
	if r.PictureURL != "https://pic.url/1" {
		t.Errorf("PictureURL: expected https://pic.url/1, got %s", r.PictureURL)
	}
}

func TestSearchArtists_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(ArtistSearchResponse{Items: []Artist{}, TotalCount: 0}), nil
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
	if track.ID != "tidal:123" {
		t.Errorf("ID: expected tidal:123, got %s", track.ID)
	}
	if track.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", track.Title)
	}
	if track.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", track.Artist)
	}
	if track.Album != "Test Album" {
		t.Errorf("Album: expected Test Album, got %s", track.Album)
	}
	if track.Duration != 200 {
		t.Errorf("Duration: expected 200, got %d", track.Duration)
	}
	if track.ISRC != "USABC123" {
		t.Errorf("ISRC: expected USABC123, got %s", track.ISRC)
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
	if album.ID != "tidal:789" {
		t.Errorf("ID: expected tidal:789, got %s", album.ID)
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
	if artist.ID != "tidal:456" {
		t.Errorf("ID: expected tidal:456, got %s", artist.ID)
	}
	if artist.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", artist.Name)
	}
	if artist.PictureURL != "https://pic.url/1" {
		t.Errorf("PictureURL: expected https://pic.url/1, got %s", artist.PictureURL)
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

// ─── GetTrackByISRC ──────────────────────────────────────────────

func TestGetTrackByISRC_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{
			Items: []Track{{
				ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
				Artist: ArtistRef{ID: 456, Name: "Test Artist"},
				Album:  AlbumRef{ID: 789, Title: "Test Album"},
			}},
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

// ─── GetStreamURL ────────────────────────────────────────────────

func TestGetStreamURL_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/tracks/123/streamurl") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(StreamURLResponse{
			URL:   "https://stream.tidal.com/audio",
			Codec: "FLAC",
		}), nil
	})
	url, err := c.GetStreamURL("123", "lossless")
	if err != nil {
		t.Fatal(err)
	}
	if url != "https://stream.tidal.com/audio" {
		t.Errorf("URL: expected https://stream.tidal.com/audio, got %s", url)
	}
}

func TestGetStreamURL_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return errJSON(404, "not found"), nil
	})
	_, err := c.GetStreamURL("999", "lossless")
	if err == nil {
		t.Fatal("expected error for missing stream URL")
	}
}

// ─── Request verification ────────────────────────────────────────

func TestRequestHeaders(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(SearchResponse{Items: []Track{}, TotalCount: 0}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("X-Tidal-Token") == "" {
		t.Error("missing X-Tidal-Token header")
	}
	if captured.Header.Get("User-Agent") == "" {
		t.Error("missing User-Agent header")
	}
}
