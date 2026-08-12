package scrobble

import "testing"

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

	err := c.ScrobbleLastFM(Track{TrackName: "Test"}, "session")
	if err == nil {
		t.Fatal("expected error when last.fm not configured (no api key)")
	}

	c2 := NewClient("key", "", "")
	err = c2.ScrobbleLastFM(Track{}, "")
	if err == nil {
		t.Fatal("expected error when session key is empty")
	}
}

func TestScrobbleListenBrainz_NotConfigured(t *testing.T) {
	c := NewClient("", "", "")
	err := c.ScrobbleListenBrainz(Track{})
	if err == nil {
		t.Fatal("expected error when listenbrainz not configured")
	}
}
