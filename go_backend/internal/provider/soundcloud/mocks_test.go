package soundcloud

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
)

type mockTransport struct {
	roundTrip func(req *http.Request) (*http.Response, error)
}

func (m *mockTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	return m.roundTrip(req)
}

func mockClient(handler func(req *http.Request) (*http.Response, error)) *Client {
	return &Client{
		http:     &http.Client{Transport: &mockTransport{roundTrip: handler}},
		clientID: "test-client-id",
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

func errSCResponse(status int) *http.Response {
	return &http.Response{
		StatusCode: status,
		Body:       io.NopCloser(strings.NewReader(`{"error":"not found"}`)),
		Header:     make(http.Header),
	}
}
