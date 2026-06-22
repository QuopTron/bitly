package qobuz

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
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

func testClient(handler http.Handler) *Client {
	return &Client{
		httpClient:  &http.Client{Transport: &testTransport{handler: handler}},
		cache:       make(map[string]*cacheEntry),
		stopCleanup: make(chan struct{}),
	}
}

func TestGetJSON_Success(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.Contains(r.URL.String(), "test-param=test-val") {
			t.Errorf("unexpected params: %s", r.URL.RawQuery)
		}
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": true,
			"data":    map[string]string{"key": "value"},
		})
	})
	c := testClient(handler)

	data, err := c.getJSON("/test", map[string]string{"test-param": "test-val"})
	if err != nil {
		t.Fatal(err)
	}
	var result map[string]string
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatal(err)
	}
	if result["key"] != "value" {
		t.Errorf("key = %q", result["key"])
	}
}

func TestGetJSON_HTTPError(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		fmt.Fprint(w, `not found`)
	})
	c := testClient(handler)
	_, err := c.getJSON("/test", nil)
	if err == nil {
		t.Fatal("expected error for 404")
	}
}

func TestGetJSON_APIFailure(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false, "data": nil,
		})
	})
	c := testClient(handler)
	_, err := c.getJSON("/test", nil)
	if err == nil || !strings.Contains(err.Error(), "success=false") {
		t.Fatalf("unexpected error: %v", err)
	}
}
