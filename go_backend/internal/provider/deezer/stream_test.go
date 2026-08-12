package deezer

import (
	"net/http"
	"strings"
	"testing"
)

func TestGetStreamURL_NoARL(t *testing.T) {
	c := NewClient(nil)
	_, err := c.GetStreamURL("123", "lossless")
	if err == nil {
		t.Fatal("expected error without ARL")
	}
}

func TestGetStreamURL_Success(t *testing.T) {
	c := NewClient(&http.Client{Transport: &mockTransport{roundTrip: func(req *http.Request) (*http.Response, error) {
		return okJSON(Track{
			ID: 123, Title: "Test", Duration: 200,
			MD5Origin: "abcdef123456",
			Artist:    ArtistRef{},
			Album:     AlbumRef{},
		}), nil
	}}})
	c.SetARL("test-arl")
	url, err := c.GetStreamURL("123", "lossless")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(url, "e-cdns-proxy-") {
		t.Errorf("expected CDN URL, got %s", url)
	}
}
