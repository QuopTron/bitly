package musicbrainz

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

type mockTransport struct {
	roundTrip func(req *http.Request) (*http.Response, error)
}

func (m *mockTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	return m.roundTrip(req)
}

func mockClient(handler func(req *http.Request) (*http.Response, error)) *Client {
	return &Client{
		http:  &http.Client{Transport: &mockTransport{roundTrip: handler}},
		app:   "BitlyTest/1.0",
		limit: httpclient.NewRateLimiter(httpclient.RateLimitConfig{RequestsPerSecond: 10000, Burst: 10000}),
	}
}

func okJSON(body interface{}) *http.Response {
	b, _ := json.Marshal(body)
	return &http.Response{
		StatusCode: http.StatusOK,
		Body:       io.NopCloser(strings.NewReader(string(b))),
		Header:     make(http.Header),
	}
}
