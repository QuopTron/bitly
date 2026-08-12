package scrobble

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestScrobbleLastFM_WithMockServer(t *testing.T) {
	var requests int
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		if err := r.ParseForm(); err != nil {
			t.Fatalf("parse form: %v", err)
		}

		tests := []struct{ key, want string }{
			{"method", "track.scrobble"},
			{"api_key", "test-api-key"},
			{"sk", "test-session"},
			{"track", "In the End"},
			{"artist", "Linkin Park"},
			{"album", "Hybrid Theory"},
			{"format", "json"},
		}
		for _, tt := range tests {
			if got := r.Form.Get(tt.key); got != tt.want {
				t.Errorf("form[%q] = %q, want %q", tt.key, got, tt.want)
			}
		}

		if got := r.Form.Get("duration"); got != "223" {
			t.Errorf("form[duration] = %q, want 223", got)
		}

		if ct := r.Header.Get("Content-Type"); ct != "application/x-www-form-urlencoded" {
			t.Errorf("Content-Type = %q, want application/x-www-form-urlencoded", ct)
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"scrobbles":{"@attr":{"accepted":1}}}`))
	}))
	defer server.Close()

	c := &Client{
		lastfmKey: "test-api-key",
		lastfmURL: server.URL + "/",
		http:      server.Client(),
	}

	track := Track{
		TrackName:  "In the End",
		ArtistName: "Linkin Park",
		AlbumName:  "Hybrid Theory",
		DurationMs: 223000,
		Timestamp:  time.Now().Unix(),
	}

	err := c.ScrobbleLastFM(track, "test-session")
	if err != nil {
		t.Fatalf("ScrobbleLastFM failed: %v", err)
	}
	if requests != 1 {
		t.Errorf("expected 1 request, got %d", requests)
	}
}

func TestScrobbleLastFM_HTTPError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	c := &Client{
		lastfmKey: "key",
		lastfmURL: server.URL + "/",
		http:      server.Client(),
	}

	track := Track{
		TrackName:  "Test",
		ArtistName: "Artist",
		Timestamp:  time.Now().Unix(),
	}

	err := c.ScrobbleLastFM(track, "session")
	if err != nil {
		t.Fatalf("ScrobbleLastFM should not return error on non-2xx: %v", err)
	}
}

func TestScrobbleLastFM_WithMultipleTracks(t *testing.T) {
	var requests int
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		if err := r.ParseForm(); err != nil {
			t.Fatalf("parse form: %v", err)
		}
		if r.Form.Get("track") == "Song A" {
			if r.Form.Get("duration") != "180" {
				t.Errorf("duration for Song A = %s, want 180", r.Form.Get("duration"))
			}
		}
		if r.Form.Get("track") == "Song B" {
			if r.Form.Get("duration") != "240" {
				t.Errorf("duration for Song B = %s, want 240", r.Form.Get("duration"))
			}
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	c := &Client{
		lastfmKey: "key",
		lastfmURL: server.URL + "/",
		http:      server.Client(),
	}

	err := c.ScrobbleLastFM(Track{
		TrackName: "Song A", ArtistName: "Artist A",
		DurationMs: 180000, Timestamp: 1000,
	}, "session")
	if err != nil {
		t.Fatalf("first scrobble failed: %v", err)
	}

	err = c.ScrobbleLastFM(Track{
		TrackName: "Song B", ArtistName: "Artist B",
		DurationMs: 240000, Timestamp: 1001,
	}, "session")
	if err != nil {
		t.Fatalf("second scrobble failed: %v", err)
	}

	if requests != 2 {
		t.Errorf("expected 2 requests, got %d", requests)
	}
}
