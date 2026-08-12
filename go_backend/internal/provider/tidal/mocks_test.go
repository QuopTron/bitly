package tidal

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
)

type mockTransport struct {
	roundTrip func(req *http.Request) (*http.Response, error)
}

func (m *mockTransport) RoundTrip(req *http.Request) (*http.Response, error) {		return m.roundTrip(req)
	}

func mockClient(handler func(req *http.Request) (*http.Response, error)) *Client {
	return NewClient(&http.Client{Transport: &mockTransport{roundTrip: handler}}, "", "")
}

func okJSON(body interface{}) *http.Response {
	b, _ := json.Marshal(body)
	return &http.Response{
		StatusCode: http.StatusOK,
		Body:       io.NopCloser(strings.NewReader(string(b))),
		Header:     make(http.Header),
	}
}

func errJSON(status int, msg string) *http.Response {
	return &http.Response{
		StatusCode: status,
		Body:       io.NopCloser(strings.NewReader(`{"error":"`+msg+`"}`)),
		Header:     make(http.Header),
	}
}
