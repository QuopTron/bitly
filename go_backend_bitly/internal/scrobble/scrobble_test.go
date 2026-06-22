package scrobble

import (
	"crypto/md5"
	"fmt"
	"net/url"
	"testing"
	"time"
)

func TestLastFMSignature(t *testing.T) {
	params := url.Values{}
	params.Set("method", "track.scrobble")
	params.Set("artist", "Test Artist")
	params.Set("track", "Test Track")
	params.Set("api_key", "key123")
	params.Set("sk", "sk123")
	params.Set("format", "json")

	sig := lastfmSignature(params, "secret456")
	if sig == "" {
		t.Fatal("empty signature")
	}
	if len(sig) != 32 {
		t.Errorf("expected 32-char MD5, got %d", len(sig))
	}
}

func TestLastFMSignature_ExcludesFormatAndApiSig(t *testing.T) {
	params := url.Values{}
	params.Set("api_sig", "should_be_ignored")
	params.Set("format", "should_be_ignored")
	params.Set("a", "1")

	sig := lastfmSignature(params, "secret")
	expected := fmt.Sprintf("%x", md5.Sum([]byte("a1secret")))
	if sig != expected {
		t.Errorf("signature = %q, want %q", sig, expected)
	}
}

func TestBuildTrackMeta_AllFields(t *testing.T) {
	track := &TrackInfo{
		Artist: "Artist", Track: "Song", Album: "Album",
		Duration: 200, TrackNumber: 3, MBID: "mbid-123",
	}
	meta := buildTrackMeta(track)
	if meta.ArtistName != "Artist" || meta.TrackName != "Song" {
		t.Error("basic fields mismatch")
	}
	if meta.ReleaseName != "Album" {
		t.Error("ReleaseName not set")
	}
	if meta.AdditionalInfo.DurationMs != 200000 {
		t.Errorf("DurationMs = %d", meta.AdditionalInfo.DurationMs)
	}
	if meta.AdditionalInfo.TrackNumber != 3 {
		t.Errorf("TrackNumber = %d", meta.AdditionalInfo.TrackNumber)
	}
	if meta.AdditionalInfo.MusicBrainzID != "mbid-123" {
		t.Errorf("MBID = %q", meta.AdditionalInfo.MusicBrainzID)
	}
}

func TestBuildTrackMeta_Minimal(t *testing.T) {
	meta := buildTrackMeta(&TrackInfo{Artist: "A", Track: "T"})
	if meta.AdditionalInfo.DurationMs != 0 {
		t.Error("expected zero DurationMs")
	}
}

func TestNowPlaying_InvalidJSON(t *testing.T) {
	err := NowPlaying("{bad json}")
	if err == nil {
		t.Fatal("expected error for invalid JSON")
	}
}

func TestScrobble_InvalidJSON(t *testing.T) {
	err := Scrobble("{bad json}")
	if err == nil {
		t.Fatal("expected error for invalid JSON")
	}
}

func TestSetupConfig_InvalidJSON(t *testing.T) {
	err := SetupConfig("{bad}")
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestNowPlaying_EmptyConfig(t *testing.T) {
	configCache = nil
	configCacheTime = time.Time{}
	err := NowPlaying(`{"artist":"A","track":"T"}`)
	if err != nil {
		t.Logf("NowPlaying with no DB returned: %v (acceptable)", err)
	}
}

func TestHTTPTimeoutConstant(t *testing.T) {
	if httpTimeout != 10*time.Second {
		t.Errorf("httpTimeout = %v", httpTimeout)
	}
}
