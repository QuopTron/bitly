package scrobble

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestNewClient(t *testing.T) {
	c := NewClient("key", "secret", "token")
	if c == nil {
		t.Fatal("expected non-nil client")
	}
	if c.lastfmKey != "key" {
		t.Errorf("expected lastfmKey 'key', got %q", c.lastfmKey)
	}
	if c.lastfmSecret != "secret" {
		t.Errorf("expected lastfmSecret 'secret', got %q", c.lastfmSecret)
	}
	if c.lbToken != "token" {
		t.Errorf("expected lbToken 'token', got %q", c.lbToken)
	}
	if c.http == nil {
		t.Error("expected non-nil HTTP client")
	}
}

func TestNewClient_Empty(t *testing.T) {
	c := NewClient("", "", "")
	if c == nil {
		t.Fatal("expected non-nil client")
	}
	if c.http == nil {
		t.Error("expected non-nil HTTP client even with empty config")
	}
}

func TestScrobbleLastFM_NotConfigured(t *testing.T) {
	c := NewClient("", "", "")

	// No lastfmKey
	err := c.ScrobbleLastFM(Track{TrackName: "Test"}, "session")
	if err == nil {
		t.Fatal("expected error when last.fm not configured (no api key)")
	}

	// Has key but no session
	c2 := NewClient("key", "", "")
	err = c2.ScrobbleLastFM(Track{}, "")
	if err == nil {
		t.Fatal("expected error when session key is empty")
	}
}

func TestScrobbleLastFM_WithMockServer(t *testing.T) {
	var requests int
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		if err := r.ParseForm(); err != nil {
			t.Fatalf("parse form: %v", err)
		}

		// Verify form fields
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

		// Verify duration (ms → seconds)
		if got := r.Form.Get("duration"); got != "223" {
			t.Errorf("form[duration] = %q, want %q (223s from 223000ms)", got, "223")
		}

		// Verify content type
		if ct := r.Header.Get("Content-Type"); ct != "application/x-www-form-urlencoded" {
			t.Errorf("Content-Type = %q, want application/x-www-form-urlencoded", ct)
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"scrobbles":{"@attr":{"accepted":1}}}`))
	}))
	defer server.Close()

	// Create client pointing to our test server via lastfmURL override
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

	// Should NOT error because ScrobbleLastFM doesn't check status code
	err := c.ScrobbleLastFM(track, "session")
	if err != nil {
		t.Fatalf("ScrobbleLastFM should not return error on non-2xx: %v", err)
	}
}

func TestScrobbleListenBrainz_NotConfigured(t *testing.T) {
	c := NewClient("", "", "")
	err := c.ScrobbleListenBrainz(Track{})
	if err == nil {
		t.Fatal("expected error when listenbrainz not configured")
	}
}

func TestScrobbleListenBrainz_WithMockServer(t *testing.T) {
	var requests int
	var gotAuth, gotContentType string

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		gotAuth = r.Header.Get("Authorization")
		gotContentType = r.Header.Get("Content-Type")

		// Verify method and path
		if r.Method != "POST" {
			t.Errorf("method = %q, want POST", r.Method)
		}

		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	c := &Client{
		lbToken: "test-lb-token",
		lbURL:   server.URL + "/1/submit-listens",
		http:    server.Client(),
	}

	track := Track{
		TrackName:  "Bohemian Rhapsody",
		ArtistName: "Queen",
		AlbumName:  "A Night at the Opera",
		DurationMs: 354000,
		Timestamp:  time.Now().Unix(),
	}

	err := c.ScrobbleListenBrainz(track)
	if err != nil {
		t.Fatalf("ScrobbleListenBrainz failed: %v", err)
	}
	if requests != 1 {
		t.Errorf("expected 1 request, got %d", requests)
	}
	if gotAuth != "Token test-lb-token" {
		t.Errorf("Authorization = %q, want 'Token test-lb-token'", gotAuth)
	}
	if gotContentType != "application/json" {
		t.Errorf("Content-Type = %q, want application/json", gotContentType)
	}
}

func TestScrobbleListenBrainz_HTTPError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"code":401,"message":"invalid auth"}`))
	}))
	defer server.Close()

	c := &Client{
		lbToken: "bad-token",
		lbURL:   server.URL + "/1/submit-listens",
		http:    server.Client(),
	}

	err := c.ScrobbleListenBrainz(Track{
		TrackName:  "Test",
		ArtistName: "Artist",
		Timestamp:  time.Now().Unix(),
	})

	// ListenBrainz doesn't check status code either, so no error expected
	if err != nil {
		t.Fatalf("ScrobbleListenBrainz should not error on non-2xx: %v", err)
	}
}

func TestScrobbleLastFM_WithMultipleTracks(t *testing.T) {
	var requests int
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		if err := r.ParseForm(); err != nil {
			t.Fatalf("parse form: %v", err)
		}
		// Track-specific fields
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

	// First track
	err := c.ScrobbleLastFM(Track{
		TrackName:  "Song A",
		ArtistName: "Artist A",
		DurationMs: 180000,
		Timestamp:  1000,
	}, "session")
	if err != nil {
		t.Fatalf("first scrobble failed: %v", err)
	}

	// Second track
	err = c.ScrobbleLastFM(Track{
		TrackName:  "Song B",
		ArtistName: "Artist B",
		DurationMs: 240000,
		Timestamp:  1001,
	}, "session")
	if err != nil {
		t.Fatalf("second scrobble failed: %v", err)
	}

	if requests != 2 {
		t.Errorf("expected 2 requests, got %d", requests)
	}
}
