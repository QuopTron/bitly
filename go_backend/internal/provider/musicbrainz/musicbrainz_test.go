package musicbrainz

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
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{
				{
					"id": "rec123", "title": "Test Track", "length": 200000,
					"isrcs":        []map[string]interface{}{{"id": "USABC123"}},
					"artist-credit": []map[string]interface{}{
						{"name": "Test Artist", "artist": map[string]interface{}{"id": "art456"}},
					},
					"releases": []map[string]interface{}{
						{"id": "rel789", "title": "Test Album"},
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
	if r.ID != "mb:rec123" {
		t.Errorf("ID: expected mb:rec123, got %s", r.ID)
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
		t.Errorf("Duration: expected 200 (seconds), got %d", r.Duration)
	}
	if r.ISRC != "USABC123" {
		t.Errorf("ISRC: expected USABC123, got %s", r.ISRC)
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

// ─── SearchAlbums ────────────────────────────────────────────────

func TestSearchAlbums_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"releases": []map[string]interface{}{
				{
					"id": "rel789", "title": "Test Album", "date": "2024-01-15",
					"track-count": 12,
					"artist-credit": []map[string]interface{}{
						{"name": "Test Artist", "artist": map[string]interface{}{"id": "art456"}},
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
	if r.ID != "mb:rel789" {
		t.Errorf("ID: expected mb:rel789, got %s", r.ID)
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
		return okJSON(map[string]interface{}{
			"artists": []map[string]interface{}{
				{"id": "art456", "name": "Test Artist"},
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
	if r.ID != "mb:art456" {
		t.Errorf("ID: expected mb:art456, got %s", r.ID)
	}
	if r.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", r.Name)
	}
}

// ─── GetTrack ────────────────────────────────────────────────────

func TestGetTrack_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{
				{
					"id": "rec123", "title": "Test Track", "length": 200000,
					"isrcs":        []map[string]interface{}{},
					"artist-credit": []map[string]interface{}{
						{"name": "Test Artist", "artist": map[string]interface{}{"id": "art456"}},
					},
					"releases": []map[string]interface{}{
						{"id": "rel789", "title": "Test Album"},
					},
				},
			},
		}), nil
	})
	track, err := c.GetTrack("rec123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "mb:rec123" {
		t.Errorf("ID: expected mb:rec123, got %s", track.ID)
	}
	if track.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", track.Title)
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

// ─── GetAlbum ────────────────────────────────────────────────────

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"id": "rel789", "title": "Test Album", "date": "2024-01-15",
			"track-count": 12,
			"artist-credit": []map[string]interface{}{
				{"name": "Test Artist", "artist": map[string]interface{}{"id": "art456"}},
			},
		}), nil
	})
	album, err := c.GetAlbum("rel789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "mb:rel789" {
		t.Errorf("ID: expected mb:rel789, got %s", album.ID)
	}
	if album.Title != "Test Album" {
		t.Errorf("Title: expected Test Album, got %s", album.Title)
	}
	if album.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", album.Artist)
	}
}

// ─── GetArtist ───────────────────────────────────────────────────

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"id": "art456", "name": "Test Artist",
		}), nil
	})
	artist, err := c.GetArtist("art456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "mb:art456" {
		t.Errorf("ID: expected mb:art456, got %s", artist.ID)
	}
	if artist.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", artist.Name)
	}
}

// ─── GetTrackByISRC ──────────────────────────────────────────────

func TestGetTrackByISRC_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{
				{
					"id": "rec123", "title": "Test Track", "length": 200000,
					"isrcs":        []map[string]interface{}{{"id": "USABC123"}},
					"artist-credit": []map[string]interface{}{},
					"releases":      []map[string]interface{}{},
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
		return okJSON(map[string]interface{}{"recordings": []map[string]interface{}{}}), nil
	})
	_, err := c.GetTrackByISRC("USNONEXISTENT")
	if err == nil {
		t.Fatal("expected error for missing ISRC")
	}
}

// ─── GetStreamURL ────────────────────────────────────────────────

func TestGetStreamURL_ReturnsError(t *testing.T) {
	c := mockClient(nil)
	_, err := c.GetStreamURL("123", "lossless")
	if err == nil {
		t.Fatal("expected error (metadata-only)")
	}
}

// ─── Request verification ────────────────────────────────────────

func TestMusicBrainzUserAgent(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(map[string]interface{}{"recordings": []map[string]interface{}{}}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("User-Agent") == "" {
		t.Error("missing User-Agent header")
	}
}

func TestMusicBrainzFormatJSON(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(map[string]interface{}{"recordings": []map[string]interface{}{}}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.URL.Query().Get("fmt") != "json" {
		t.Errorf("fmt param: expected json, got %s", captured.URL.Query().Get("fmt"))
	}
}
