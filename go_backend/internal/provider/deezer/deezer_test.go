package deezer

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
	return NewClient(&http.Client{Transport: &mockTransport{roundTrip: handler}})
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
			Data: []Track{
				{
					ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
					Artist: ArtistRef{ID: 456, Name: "Test Artist"},
					Album:  AlbumRef{ID: 789, Title: "Test Album", Cover: "https://cover.url/1"},
				},
			},
			Total: 1,
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
	if r.ID != "deezer:123" {
		t.Errorf("ID: expected deezer:123, got %s", r.ID)
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
	if r.Provider != "deezer" {
		t.Errorf("Provider: expected deezer, got %s", r.Provider)
	}
}

func TestSearchTracks_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(SearchResponse{Data: []Track{}, Total: 0}), nil
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
			"data": []map[string]interface{}{
				{
					"id": 789, "title": "Test Album",
					"cover": "https://cover.url/2",
					"artist": map[string]interface{}{"id": 456, "name": "Test Artist"},
				},
			},
			"total": 1,
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
	if r.ID != "deezer:789" {
		t.Errorf("ID: expected deezer:789, got %s", r.ID)
	}
	if r.Title != "Test Album" {
		t.Errorf("Title: expected Test Album, got %s", r.Title)
	}
	if r.Provider != "deezer" {
		t.Errorf("Provider: expected deezer, got %s", r.Provider)
	}
}

func TestSearchAlbums_Empty(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{"data": []map[string]interface{}{}, "total": 0}), nil
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
			"data": []map[string]interface{}{
				{"id": 456, "name": "Test Artist", "picture": "https://pic.url/1"},
			},
			"total": 1,
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
	if r.ID != "deezer:456" {
		t.Errorf("ID: expected deezer:456, got %s", r.ID)
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
			Artist: ArtistRef{ID: 456, Name: "Test Artist"},
			Album:  AlbumRef{ID: 789, Title: "Test Album", Cover: "https://cover.url/1"},
		}), nil
	})
	track, err := c.GetTrack("123")
	if err != nil {
		t.Fatal(err)
	}
	if track.ID != "deezer:123" {
		t.Errorf("ID: expected deezer:123, got %s", track.ID)
	}
	if track.Title != "Test Track" {
		t.Errorf("Title: expected Test Track, got %s", track.Title)
	}
	if track.Artist != "Test Artist" {
		t.Errorf("Artist: expected Test Artist, got %s", track.Artist)
	}
}

func TestGetTrack_InvalidID(t *testing.T) {
	c := mockClient(nil)
	_, err := c.GetTrack("abc")
	if err == nil {
		t.Fatal("expected error for invalid ID")
	}
}

// ─── GetAlbum ────────────────────────────────────────────────────

func TestGetAlbum_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(Album{
			ID: 789, Title: "Test Album", ReleaseDate: "2024-01-01",
			CoverBig: "https://cover.url/2", TrackCount: 12,
			Artist: ArtistRef{ID: 456, Name: "Test Artist"},
		}), nil
	})
	album, err := c.GetAlbum("789")
	if err != nil {
		t.Fatal(err)
	}
	if album.ID != "deezer:789" {
		t.Errorf("ID: expected deezer:789, got %s", album.ID)
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

func TestGetAlbum_InvalidID(t *testing.T) {
	c := mockClient(nil)
	_, err := c.GetAlbum("abc")
	if err == nil {
		t.Fatal("expected error for invalid ID")
	}
}

// ─── GetArtist ───────────────────────────────────────────────────

func TestGetArtist_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(Artist{
			ID: 456, Name: "Test Artist", PictureBig: "https://pic.url/1",
		}), nil
	})
	artist, err := c.GetArtist("456")
	if err != nil {
		t.Fatal(err)
	}
	if artist.ID != "deezer:456" {
		t.Errorf("ID: expected deezer:456, got %s", artist.ID)
	}
	if artist.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", artist.Name)
	}
}

// ─── GetTrackByISRC ──────────────────────────────────────────────

func TestGetTrackByISRC_Success(t *testing.T) {
	callCount := 0
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		callCount++
		if callCount == 1 {
			// First call: search by ISRC
			return okJSON(SearchResponse{
				Data: []Track{
					{
						ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
						Artist: ArtistRef{ID: 456, Name: "Test Artist"},
						Album:  AlbumRef{ID: 789, Title: "Test Album"},
					},
				},
				Total: 1,
			}), nil
		}
		// Second call: get track by ID (returns full metadata)
		return okJSON(Track{
			ID: 123, Title: "Test Track", Duration: 200, ISRC: "USABC123",
			Artist: ArtistRef{ID: 456, Name: "Test Artist"},
			Album:  AlbumRef{ID: 789, Title: "Test Album"},
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
		return okJSON(SearchResponse{Data: []Track{}, Total: 0}), nil
	})
	_, err := c.GetTrackByISRC("USNONEXISTENT")
	if err == nil {
		t.Fatal("expected error for missing ISRC")
	}
}

// ─── GetStreamURL ────────────────────────────────────────────────

func TestGetStreamURL_NoARL(t *testing.T) {
	c := mockClient(nil)
	_, err := c.GetStreamURL("123", "lossless")
	if err == nil {
		t.Fatal("expected error without ARL")
	}
}

func TestGetStreamURL_Success(t *testing.T) {
	c := NewClient(&http.Client{Transport: &mockTransport{roundTrip: func(req *http.Request) (*http.Response, error) {
		return okJSON(Track{
			ID: 123, Title: "Test", Duration: 200,
			MD5Origin: "abcdef123456",
			Artist: ArtistRef{},
			Album:  AlbumRef{},
		}), nil
	}}})
	c.SetARL("test-arl")
	url, err := c.GetStreamURL("123", "lossless")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(url, "e-cdns-proxy-") {
		t.Errorf("expected CDN URL, got %s", url)
	}
}
