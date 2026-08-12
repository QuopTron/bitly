package musicbrainz

import (
	"net/http"
	"strings"
	"testing"
)

func TestGetStreamURL_ReturnsError(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		t.Error("GetStreamURL should not make HTTP requests (metadata only)")
		return nil, nil
	})
	_, err := c.GetStreamURL("rec-123", "flac")
	if err == nil {
		t.Fatal("expected error for metadata-only provider")
	}
	if !strings.Contains(err.Error(), "no stream URLs") {
		t.Errorf("expected 'no stream URLs' error, got: %v", err)
	}
}

func TestCoverArtURL_WithReleaseID(t *testing.T) {
	url := coverArtURL("release-abc")
	expected := "https://coverartarchive.org/release/release-abc/front-250.jpg"
	if url != expected {
		t.Errorf("expected %s, got %s", expected, url)
	}
}

func TestCoverArtURL_EmptyReleaseID(t *testing.T) {
	url := coverArtURL("")
	if url != "" {
		t.Errorf("expected empty string, got %s", url)
	}
}

func TestMusicBrainzRequestHeaders(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(map[string]interface{}{
			"recordings": []map[string]interface{}{},
		}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("User-Agent") != "BitlyTest/1.0" {
		t.Errorf("User-Agent: expected BitlyTest/1.0, got %s", captured.Header.Get("User-Agent"))
	}
	if captured.Header.Get("Accept") != "application/json" {
		t.Errorf("Accept: expected application/json, got %s", captured.Header.Get("Accept"))
	}
}
