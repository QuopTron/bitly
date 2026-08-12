package scrobble

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestScrobbleListenBrainz_WithMockServer(t *testing.T) {
	var requests int
	var gotAuth, gotContentType string

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		gotAuth = r.Header.Get("Authorization")
		gotContentType = r.Header.Get("Content-Type")

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
		TrackName: "Test", ArtistName: "Artist",
		Timestamp: time.Now().Unix(),
	})

	if err != nil {
		t.Fatalf("ScrobbleListenBrainz should not error on non-2xx: %v", err)
	}
}
