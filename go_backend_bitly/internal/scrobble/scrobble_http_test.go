package scrobble

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

type testTransport struct {
	handler http.Handler
}

func (t *testTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	w := httptest.NewRecorder()
	t.handler.ServeHTTP(w, req)
	return w.Result(), nil
}

func testHTTPClient(handler http.Handler) *http.Client {
	return &http.Client{Transport: &testTransport{handler: handler}}
}

func TestLastFMNowPlaying_SendsRequest(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			t.Errorf("method = %s", r.Method)
		}
		if r.Header.Get("Content-Type") != "application/x-www-form-urlencoded" {
			t.Error("wrong content type")
		}
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{}`)
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()
	err := lastfmNowPlaying(&LastFMConfig{Enabled: true, APIKey: "k", APISecret: "s", SessionKey: "sk"}, &TrackInfo{Artist: "A", Track: "T"})
	if err != nil {
		t.Fatal(err)
	}
}

func TestLastFMScrobble_SendsRequest(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{}`)
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()
	err := lastfmScrobble(&LastFMConfig{Enabled: true, APIKey: "k", APISecret: "s", SessionKey: "sk"}, &TrackInfo{Artist: "A", Track: "T"})
	if err != nil {
		t.Fatal(err)
	}
}

func TestLastFM_APIError(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"error":4,"message":"auth failed"}`)
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()
	err := lastfmScrobble(&LastFMConfig{APIKey: "k", APISecret: "s", SessionKey: "sk"}, &TrackInfo{Artist: "A", Track: "T"})
	if err == nil || err.Error() != "last.fm API error 4: auth failed" {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestLastFM_HTTPError(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
		fmt.Fprint(w, `rate limited`)
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()
	err := lastfmScrobble(&LastFMConfig{APIKey: "k", APISecret: "s", SessionKey: "sk"}, &TrackInfo{Artist: "A", Track: "T"})
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestListenBrainzNowPlaying_SendsRequest(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Token test-token" {
			t.Error("wrong auth header")
		}
		if r.Header.Get("Content-Type") != "application/json" {
			t.Error("wrong content type")
		}
		w.WriteHeader(http.StatusOK)
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()
	err := listenBrainzNowPlaying(&ListenBrainzConfig{Enabled: true, UserToken: "test-token"}, &TrackInfo{Artist: "A", Track: "T"})
	if err != nil {
		t.Fatal(err)
	}
}

func TestListenBrainzScrobble_SendsRequest(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()
	err := listenBrainzScrobble(&ListenBrainzConfig{Enabled: true, UserToken: "tok"}, &TrackInfo{Artist: "A", Track: "T", Duration: 100})
	if err != nil {
		t.Fatal(err)
	}
}

func TestListenBrainz_HTTPError(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, `bad request`)
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()
	err := listenBrainzScrobble(&ListenBrainzConfig{UserToken: "tok"}, &TrackInfo{Artist: "A", Track: "T"})
	if err == nil {
		t.Fatal("expected error")
	}
}
