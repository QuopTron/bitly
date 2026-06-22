package spotify

import (
	"net/http"
	"testing"
	"time"
)

func TestNewClient(t *testing.T) {
	c := NewClient()
	if c == nil {
		t.Fatal("expected non-nil Client")
	}
	if c.httpClient == nil {
		t.Error("expected non-nil httpClient")
	}
	if c.httpClient.Timeout != 15*time.Second {
		t.Errorf("timeout = %v, want 15s", c.httpClient.Timeout)
	}
}

func TestSetAuthToken(t *testing.T) {
	c := NewClient()
	if c.authToken != "" {
		t.Error("expected empty auth token initially")
	}

	c.SetAuthToken("test-token-123")
	if c.authToken != "test-token-123" {
		t.Errorf("authToken = %q", c.authToken)
	}
}

func TestGetTrackMetadata_NoAuth(t *testing.T) {
	c := NewClient()
	_, err := c.GetTrackMetadata("track_id_123")
	if err == nil {
		t.Fatal("expected error when no auth token set")
	}
}

func TestSpotifyAPIConstants(t *testing.T) {
	if spotifyAPIBase != "https://api.spotify.com/v1" {
		t.Errorf("spotifyAPIBase = %q", spotifyAPIBase)
	}
}

func TestClient_DefaultTimeout(t *testing.T) {
	c := NewClient()
	if c.httpClient.Timeout != 15*time.Second {
		t.Errorf("expected 15s timeout, got %v", c.httpClient.Timeout)
	}
}

func TestClient_FieldAccess(t *testing.T) {
	c := &Client{
		httpClient: &http.Client{},
		authToken:  "test",
	}
	if c.authToken != "test" {
		t.Errorf("authToken = %q", c.authToken)
	}
}
