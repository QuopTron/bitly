package httpclient

import (
	"io"
	"net/http"
	"strings"
)

func NewBreakerTransport(inner http.RoundTripper) http.RoundTripper {
	if inner == nil {
		inner = http.DefaultTransport
	}
	return &transporteBreaker{interno: inner}
}

type transporteBreaker struct {
	interno http.RoundTripper
}

func (t *transporteBreaker) RoundTrip(req *http.Request) (*http.Response, error) {
	raw := ""
	if req != nil && req.URL != nil {
		raw = req.URL.String()
	}
	if BreakerBlocked(raw) {
		return SyntheticGatewayResponse(req), nil
	}
	resp, err := t.interno.RoundTrip(req)
	if err != nil {
		BreakerRecord(raw, 0, err)
		return resp, err
	}
	if resp != nil {
		BreakerRecord(raw, resp.StatusCode, nil)
	}
	return resp, err
}

// SyntheticGatewayResponse builds a fast HTTP 522 response (the same code
// Cloudflare returns for a dead origin) used to short-circuit parked hosts.
func SyntheticGatewayResponse(req *http.Request) *http.Response {
	return &http.Response{
		StatusCode:    522,
		Status:        "522 Origin Connection Time-out",
		Proto:         "HTTP/1.1",
		ProtoMajor:    1,
		ProtoMinor:    1,
		Header:        http.Header{},
		Body:          io.NopCloser(strings.NewReader("")),
		ContentLength: 0,
		Request:       req,
	}
}
