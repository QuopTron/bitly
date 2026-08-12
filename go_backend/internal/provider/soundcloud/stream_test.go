package soundcloud

import (
	"net/http"
	"strings"
	"testing"
)

func TestGetStreamURL_ProgressivePreferred(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"media": map[string]interface{}{
				"transcodings": []map[string]interface{}{
					{"url": "https://api.soundcloud.com/tracks/123/hls",
						"format": map[string]interface{}{"protocol": "hls"}},
					{"url": "https://api.soundcloud.com/tracks/123/progressive",
						"format": map[string]interface{}{"protocol": "progressive"}},
				},
			},
		}), nil
	})
	url, err := c.GetStreamURL("123", "mp3")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(url, "progressive") {
		t.Errorf("expected progressive URL, got: %s", url)
	}
	if !strings.Contains(url, "client_id=test-client-id") {
		t.Errorf("expected client_id param, got: %s", url)
	}
}

func TestGetStreamURL_FallbackHLS(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"media": map[string]interface{}{
				"transcodings": []map[string]interface{}{
					{"url": "https://api.soundcloud.com/tracks/123/hls-only",
						"format": map[string]interface{}{"protocol": "hls"}},
				},
			},
		}), nil
	})
	url, err := c.GetStreamURL("123", "mp3")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(url, "hls-only") {
		t.Errorf("expected HLS fallback URL, got: %s", url)
	}
}

func TestGetStreamURL_NoTranscodings(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(map[string]interface{}{
			"media": map[string]interface{}{
				"transcodings": []map[string]interface{}{},
			},
		}), nil
	})
	_, err := c.GetStreamURL("123", "mp3")
	if err == nil {
		t.Fatal("expected error for no transcodings")
	}
}

func TestSoundCloudRequestHeaders(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(map[string]interface{}{"collection": []map[string]interface{}{}}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("Accept") != "application/json" {
		t.Errorf("Accept header: expected application/json, got %s", captured.Header.Get("Accept"))
	}
	ua := captured.Header.Get("User-Agent")
	if ua == "" {
		t.Error("User-Agent header should not be empty")
	}
	if !strings.Contains(captured.URL.RawQuery, "client_id=test-client-id") {
		t.Errorf("expected client_id in query, got: %s", captured.URL.RawQuery)
	}
}
