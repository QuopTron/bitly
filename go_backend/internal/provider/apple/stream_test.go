package apple

import (
	"net/http"
	"strings"
	"testing"
)

func TestGetStreamURL_ReturnsError(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		t.Error("GetStreamURL should not make HTTP requests (DRM)")
		return okJSON(map[string]interface{}{"data": []map[string]interface{}{}}), nil
	})
	_, err := c.GetStreamURL("song123", "lossless")
	if err == nil {
		t.Fatal("expected error for DRM-protected stream")
	}
	if !strings.Contains(err.Error(), "FairPlay") {
		t.Errorf("expected FairPlay error, got: %v", err)
	}
}

func TestAppleRequestHeaders(t *testing.T) {
	var captured *http.Request
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		captured = req
		return okJSON(map[string]interface{}{
			"results": map[string]interface{}{
				"songs": map[string]interface{}{"data": []map[string]interface{}{}},
			},
		}), nil
	})
	_, _ = c.SearchTracks("test", 5)
	if captured == nil {
		t.Fatal("no request captured")
	}
	if captured.Header.Get("Authorization") != "Bearer test-token" {
		t.Errorf("Authorization header: expected Bearer test-token, got %s", captured.Header.Get("Authorization"))
	}
}
