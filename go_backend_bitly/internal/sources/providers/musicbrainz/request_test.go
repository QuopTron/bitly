package musicbrainz

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDoRequest(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"recordings":[]}`)
	}))
	defer ts.Close()

	c := GetClient()
	resp, err := c.doRequest(ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d", resp.StatusCode)
	}
}

func TestDoRequestWithRetry_OK(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(recordingResponse{})
	}))
	defer ts.Close()

	c := GetClient()
	resp, err := c.doRequestWithRetry(ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
}

func TestDoRequestWithRetry_ClientError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
	}))
	defer ts.Close()

	c := GetClient()
	_, err := c.doRequestWithRetry(ts.URL)
	if err == nil {
		t.Fatal("expected error for 400")
	}
}

func TestDoRequestWithRetry_RetryOn429(t *testing.T) {
	attempts := 0
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		if attempts < 2 {
			w.WriteHeader(http.StatusTooManyRequests)
			return
		}
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(recordingResponse{})
	}))
	defer ts.Close()

	c := GetClient()
	resp, err := c.doRequestWithRetry(ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if attempts < 2 {
		t.Errorf("expected retry on 429, attempts = %d", attempts)
	}
}
