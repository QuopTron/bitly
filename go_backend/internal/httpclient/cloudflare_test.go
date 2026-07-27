package httpclient

import (
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestIsCloudflareChallenge_CFDetection(t *testing.T) {
	body := `<!DOCTYPE html><html><head><title>Just a moment...</title></head>
	<body>Checking your browser before accessing... <div id="cf-browser-verification"></div></body></html>`
	resp := &http.Response{
		StatusCode: 403,
		Header:     http.Header{"Content-Type": []string{"text/html"}, "Server": []string{"cloudflare"}},
		Body:       io.NopCloser(strings.NewReader(body)),
	}
	if !IsCloudflareChallenge(resp) {
		t.Error("expected Cloudflare challenge detection")
	}
}

func TestIsCloudflareChallenge_NormalResponse(t *testing.T) {
	body := `{"status":"ok"}`
	resp := &http.Response{
		StatusCode: 200,
		Header:     http.Header{"Content-Type": []string{"application/json"}},
		Body:       io.NopCloser(strings.NewReader(body)),
	}
	if IsCloudflareChallenge(resp) {
		t.Error("expected no Cloudflare challenge for JSON")
	}
}

func TestIsCloudflareChallenge_NilResponse(t *testing.T) {
	if IsCloudflareChallenge(nil) {
		t.Error("expected false for nil response")
	}
}

func TestHasCFClearance_NoJar(t *testing.T) {
	if HasCFClearance(nil, "example.com") {
		t.Error("expected false with nil jar")
	}
}

func TestIsCloudflareBlocked(t *testing.T) {
	cfErr := &CloudflareError{Domain: "api.deezer.com", Status: 403}
	if !IsCloudflareBlocked(cfErr) {
		t.Error("expected true for CloudflareError")
	}
	if IsCloudflareBlocked(io.EOF) {
		t.Error("expected false for unrelated error")
	}
	if IsCloudflareBlocked(nil) {
		t.Error("expected false for nil")
	}
}

func TestCloudflareError_Message(t *testing.T) {
	err := &CloudflareError{Domain: "test.com"}
	expected := "cloudflare challenge: test.com"
	if err.Error() != expected {
		t.Errorf("expected %q, got %q", expected, err.Error())
	}
}
