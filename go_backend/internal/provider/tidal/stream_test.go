package tidal

import (
	"net/http"
	"strings"
	"testing"
)

func TestGetStreamURL_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/tracks/123/streamurl") {
			t.Errorf("unexpected path: %s", req.URL.Path)
		}
		return okJSON(StreamURLResponse{
			URL:   "https://stream.tidal.com/audio",
			Codec: "FLAC",
		}), nil
	})
	url, err := c.GetStreamURL("123", "lossless")
	if err != nil {
		t.Fatal(err)
	}
	if url != "https://stream.tidal.com/audio" {
		t.Errorf("URL: expected https://stream.tidal.com/audio, got %s", url)
	}
}

func TestGetStreamURL_NotFound(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return errJSON(404, "not found"), nil
	})
	_, err := c.GetStreamURL("999", "lossless")
	if err == nil {
		t.Fatal("expected error for missing stream URL")
	}
}

func TestRequestHeaders(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(SearchResponse{Items: []Track{}, TotalCount: 0}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("X-Tidal-Token") == "" {
		t.Error("missing X-Tidal-Token header")
	}
	if captured.Header.Get("User-Agent") == "" {
		t.Error("missing User-Agent header")
	}
}
