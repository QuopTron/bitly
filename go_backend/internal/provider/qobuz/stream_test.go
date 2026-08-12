package qobuz

import (
	"net/http"
	"testing"
)

func TestGetStreamURL_NoAuth(t *testing.T) {
	c := mockClient(nil)
	_, err := c.GetStreamURL("123", "lossless")
	if err == nil {
		t.Fatal("expected error without auth")
	}
}

func TestGetStreamURL_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		return okJSON(TrackFileURLResponse{URL: "https://stream.qobuz.com/audio"}), nil
	})
	c.userAuth = &userAuth{Token: "test-token", CredID: "test-cred"}
	url, err := c.GetStreamURL("123", "lossless")
	if err != nil {
		t.Fatal(err)
	}
	if url != "https://stream.qobuz.com/audio" {
		t.Errorf("URL: expected stream URL, got %s", url)
	}
}

func TestQobuzRequestHeaders(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(SearchResponse{}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("X-App-Id") == "" {
		t.Error("missing X-App-Id header")
	}
	if captured.Header.Get("User-Agent") == "" {
		t.Error("missing User-Agent header")
	}
}

func TestQobuzAuthToken(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(TrackFileURLResponse{URL: "https://stream.qobuz.com/audio"}), nil
	})
	c.userAuth = &userAuth{Token: "secret-token"}
	_, _ = c.GetStreamURL("123", "lossless")
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("X-User-Auth-Token") != "secret-token" {
		t.Errorf("X-User-Auth-Token: expected secret-token, got %s", captured.Header.Get("X-User-Auth-Token"))
	}
}
