package qobuz

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

type mockTransport struct {
	roundTrip func(req *http.Request) (*http.Response, error)
}

func (m *mockTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	return m.roundTrip(req)
}

func mockClient(handler func(req *http.Request) (*http.Response, error)) *Client {
	return NewClient(&http.Client{Transport: &mockTransport{roundTrip: handler}}, "")
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
		return okJSON(SearchResponse{
			Tracks: &struct {
				Items []Track `json:"items"`
				Total int     `json:"total"`
			}{
				Items: []Track{
					{
						ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
						Performer: &Artist{ID: 456, Name: "Test Artist"},
						Album:     &Album{ID: 789, Title: "Test Album", Image: Image{Large: "https://cover.url/1"}},
					},
				},
				Total: 1,
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
	if r.ID != "qobuz:123" {
		t.Errorf("ID: expected qobuz:123, got %s", r.ID)
	}
	if r.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", r.Title)
	}
	if r.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", r.Artist)
	}
	if r.Duration != 200 {
		t.Errorf("Duration: expected 200, got %d", r.Duration)
	}
	if r.ISRC != "USABC123" {
		t.Errorf("ISRC: expected USABC123, got %s", r.ISRC)
	}
	if r.Provider != "qobuz" {
		t.Errorf("Provider: expected qobuz, got %s", r.Provider)
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{}), nil
	})
	results, err := c.SearchTracks("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if results != nil {
		t.Errorf("expected nil, got %v", results)
	}
}

// ─── SearchAlbums ────────────────────────────────────────────────

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{
			Albums: &struct {
				Items []Album `json:"items"`
				Total int     `json:"total"`
			}{
				Items: []Album{
					{
						ID: 789, Title: "Test Album", ReleaseDate: "2024-01-01",
						TrackCount: 12, Image: Image{Large: "https://cover.url/2"},
						Artist: &Artist{ID: 456, Name: "Test Artist"},
					},
				},
				Total: 1,
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
	if r.ID != "qobuz:789" {
		t.Errorf("ID: expected qobuz:789, got %s", r.ID)
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
		return okJSON(SearchResponse{}), nil
	})
	results, err := c.SearchAlbums("nonexistent", 5)
	if err != nil {
		t.Fatal(err)
	}
	if results != nil {
		t.Errorf("expected nil, got %v", results)
	}
}

// ─── SearchArtists ───────────────────────────────────────────────

func TestSearchArtists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{
			Artists: &struct {
				Items []Artist `json:"items"`
				Total int      `json:"total"`
			}{
				Items: []Artist{
					{ID: 456, Name: "Test Artist", Image: Image{Large: "https://pic.url/1"}},
				},
				Total: 1,
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
	if r.ID != "qobuz:456" {
		t.Errorf("ID: expected qobuz:456, got %s", r.ID)
	}
	if r.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", r.Name)
	}
}

// ─── GetTrack ────────────────────────────────────────────────────

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(Track{
			ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
			Performer: &Artist{ID: 456, Name: "Test Artist"},
			Album:     &Album{ID: 789, Title: "Test Album", Image: Image{Large: "https://cover.url/1"}},
		}), nil
	})
	track, err := c.GetTrack("123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "qobuz:123" {
		t.Errorf("ID: expected qobuz:123, got %s", track.ID)
	}
	if track.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", track.Title)
	}
	if track.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", track.Artist)
	}
}

// ─── GetAlbum ────────────────────────────────────────────────────

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(Album{
			ID: 789, Title: "Test Album", ReleaseDate: "2024-01-01",
			TrackCount: 12, Image: Image{Large: "https://cover.url/2"},
			Artist: &Artist{ID: 456, Name: "Test Artist"},
		}), nil
	})
	album, err := c.GetAlbum("789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "qobuz:789" {
		t.Errorf("ID: expected qobuz:789, got %s", album.ID)
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
		return okJSON(Artist{
			ID: 456, Name: "Test Artist", Image: Image{Large: "https://pic.url/1"},
		}), nil
	})
	artist, err := c.GetArtist("456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "qobuz:456" {
		t.Errorf("ID: expected qobuz:456, got %s", artist.ID)
	}
	if artist.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", artist.Name)
	}
}

// ─── GetTrackByISRC ──────────────────────────────────────────────

func TestGetTrackByISRC_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{
			Tracks: &struct {
				Items []Track `json:"items"`
				Total int     `json:"total"`
			}{
				Items: []Track{
					{
						ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
						Performer: &Artist{ID: 456, Name: "Test Artist"},
						Album:     &Album{ID: 789, Title: "Test Album"},
					},
				},
				Total: 1,
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
		return okJSON(SearchResponse{}), nil
	})
	_, err := c.GetTrackByISRC("USNONEXISTENT")
	if err == nil {
		t.Fatal("expected error for missing ISRC")
	}
}

// ─── GetStreamURL ────────────────────────────────────────────────

func TestGetStreamURL_NoAuth(t *testing.T) {
	c := mockClient(nil)
	_, err := c.GetStreamURL("123", "lossless")
	if err == nil {
		t.Fatal("expected error without auth")
	}
}

func TestGetStreamURL_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(TrackFileURLResponse{URL: "https://stream.qobuz.com/audio"}), nil
	})
	c.userAuth = &userAuth{Token: "test-token", CredID: "test-cred"}
	url, err := c.GetStreamURL("123", "lossless")
	if err != nil {
		t.Fatal(err)
	}
	if url != "https://stream.qobuz.com/audio" {
		t.Errorf("URL: expected stream URL, got %s", url)
	}
}

// ─── Request verification ────────────────────────────────────────

func TestQobuzRequestHeaders(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(SearchResponse{}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("X-App-Id") == "" {
		t.Error("missing X-App-Id header")
	}
	if captured.Header.Get("User-Agent") == "" {
		t.Error("missing User-Agent header")
	}
}

func TestQobuzAuthToken(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(TrackFileURLResponse{URL: "https://stream.qobuz.com/audio"}), nil
	})
	c.userAuth = &userAuth{Token: "secret-token"}
	_, _ = c.GetStreamURL("123", "lossless")
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("X-User-Auth-Token") != "secret-token" {
		t.Errorf("X-User-Auth-Token: expected secret-token, got %s", captured.Header.Get("X-User-Auth-Token"))
	}
}
