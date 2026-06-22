package httpclient

import (
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

type mockTransport struct {
	statusCodes []int
	failCount   int
	attempt     int
}

func (m *mockTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	m.attempt++
	if m.attempt <= m.failCount {
		return nil, errors.New("mock network error")
	}
	statusCode := http.StatusOK
	idx := m.attempt - 1 - m.failCount
	if idx < len(m.statusCodes) {
		statusCode = m.statusCodes[idx]
	}
	return &http.Response{
		StatusCode: statusCode,
		Body:       io.NopCloser(strings.NewReader("mock body")),
	}, nil
}

func TestDefaultRetryConfig(t *testing.T) {
	cfg := DefaultRetryConfig()
	if cfg.MaxRetries != 3 {
		t.Errorf("expected MaxRetries 3, got %d", cfg.MaxRetries)
	}
	if cfg.InitialDelay != 500*time.Millisecond {
		t.Errorf("expected InitialDelay 500ms, got %v", cfg.InitialDelay)
	}
	if cfg.MaxDelay != 5*time.Second {
		t.Errorf("expected MaxDelay 5s, got %v", cfg.MaxDelay)
	}
	if cfg.Factor != 2.0 {
		t.Errorf("expected Factor 2.0, got %f", cfg.Factor)
	}
}

func TestDoWithRetry_SuccessOnFirstAttempt(t *testing.T) {
	tr := &mockTransport{statusCodes: []int{200}}
	client := &http.Client{Transport: tr}
	req, _ := http.NewRequest("GET", "http://example.com", nil)

	resp, err := DoWithRetry(client, req, DefaultRetryConfig())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	resp.Body.Close()

	if tr.attempt != 1 {
		t.Errorf("expected 1 attempt, got %d", tr.attempt)
	}
}

func TestDoWithRetry_SuccessOnRetry(t *testing.T) {
	tr := &mockTransport{statusCodes: []int{500, 502, 200}}
	client := &http.Client{Transport: tr}
	req, _ := http.NewRequest("GET", "http://example.com", nil)

	resp, err := DoWithRetry(client, req, RetryConfig{
		MaxRetries:   3,
		InitialDelay: 1 * time.Millisecond,
		MaxDelay:     5 * time.Millisecond,
		Factor:       2.0,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	resp.Body.Close()

	if tr.attempt != 3 {
		t.Errorf("expected 3 attempts, got %d", tr.attempt)
	}
}

func TestDoWithRetry_AllRetriesExhaustedWith5xx(t *testing.T) {
	tr := &mockTransport{statusCodes: []int{500, 503, 502, 500}}
	client := &http.Client{Transport: tr}
	req, _ := http.NewRequest("GET", "http://example.com", nil)

	resp, err := DoWithRetry(client, req, RetryConfig{
		MaxRetries:   2,
		InitialDelay: 1 * time.Millisecond,
		MaxDelay:     5 * time.Millisecond,
		Factor:       2.0,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	resp.Body.Close()

	expected := 3
	if tr.attempt != expected {
		t.Errorf("expected %d attempts, got %d", expected, tr.attempt)
	}
	if resp.StatusCode != 502 {
		t.Errorf("expected last status 502, got %d", resp.StatusCode)
	}
}

func TestDoWithRetry_NetworkFailureThenSuccess(t *testing.T) {
	tr := &mockTransport{failCount: 2, statusCodes: []int{200}}
	client := &http.Client{Transport: tr}
	req, _ := http.NewRequest("GET", "http://example.com", nil)

	resp, err := DoWithRetry(client, req, RetryConfig{
		MaxRetries:   3,
		InitialDelay: 1 * time.Millisecond,
		MaxDelay:     5 * time.Millisecond,
		Factor:       2.0,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	resp.Body.Close()

	if tr.attempt != 3 {
		t.Errorf("expected 3 attempts (2 fails + 1 success), got %d", tr.attempt)
	}
}

func TestDoWithRetry_AllNetworkFailures(t *testing.T) {
	tr := &mockTransport{failCount: 10}
	client := &http.Client{Transport: tr}
	req, _ := http.NewRequest("GET", "http://example.com", nil)

	_, err := DoWithRetry(client, req, RetryConfig{
		MaxRetries:   2,
		InitialDelay: 1 * time.Millisecond,
		MaxDelay:     5 * time.Millisecond,
		Factor:       2.0,
	})
	if err == nil {
		t.Fatal("expected error when all attempts fail with network errors")
	}
	if !strings.Contains(err.Error(), "request failed after") {
		t.Errorf("expected retry failure message, got: %v", err)
	}
	if tr.attempt != 3 {
		t.Errorf("expected 3 attempts, got %d", tr.attempt)
	}
}

func TestDoWithRetry_ExponentialBackoff(t *testing.T) {
	tr := &mockTransport{statusCodes: []int{500, 500, 500, 200}}
	client := &http.Client{Transport: tr}
	req, _ := http.NewRequest("GET", "http://example.com", nil)

	start := time.Now()
	resp, err := DoWithRetry(client, req, RetryConfig{
		MaxRetries:   3,
		InitialDelay: 10 * time.Millisecond,
		MaxDelay:     50 * time.Millisecond,
		Factor:       2.0,
	})
	elapsed := time.Since(start)

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	resp.Body.Close()

	if elapsed < 10*time.Millisecond {
		t.Error("backoff should cause measurable delay between retries")
	}
}

func TestDoWithRetry_MaxDelayCapsBackoff(t *testing.T) {
	tr := &mockTransport{statusCodes: []int{500, 500, 500, 200}}
	client := &http.Client{Transport: tr}
	req, _ := http.NewRequest("GET", "http://example.com", nil)

	start := time.Now()
	resp, err := DoWithRetry(client, req, RetryConfig{
		MaxRetries:   3,
		InitialDelay: 100 * time.Millisecond,
		MaxDelay:     20 * time.Millisecond,
		Factor:       4.0,
	})
	elapsed := time.Since(start)

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	resp.Body.Close()

	if elapsed > 200*time.Millisecond {
		t.Errorf("backoff should be capped by MaxDelay, elapsed=%v", elapsed)
	}
}

func TestDoWithRetry_NoRetries(t *testing.T) {
	tr := &mockTransport{statusCodes: []int{500}}
	client := &http.Client{Transport: tr}
	req, _ := http.NewRequest("GET", "http://example.com", nil)

	resp, err := DoWithRetry(client, req, RetryConfig{
		MaxRetries:   0,
		InitialDelay: 10 * time.Millisecond,
		MaxDelay:     50 * time.Millisecond,
		Factor:       2.0,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	resp.Body.Close()

	if tr.attempt != 1 {
		t.Errorf("expected 1 attempt with MaxRetries=0, got %d", tr.attempt)
	}
}

func TestDoWithRetry_ZeroValueConfig(t *testing.T) {
	tr := &mockTransport{statusCodes: []int{200}}
	client := &http.Client{Transport: tr}
	req, _ := http.NewRequest("GET", "http://example.com", nil)

	resp, err := DoWithRetry(client, req, RetryConfig{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	resp.Body.Close()

	if tr.attempt != 1 {
		t.Errorf("expected 1 attempt, got %d", tr.attempt)
	}
}

func TestContainsCloudflareChallenge(t *testing.T) {
	tests := []struct {
		name string
		body string
		want bool
	}{
		{
			name: "cf-browser-verification",
			body: `<html><body>cf-browser-verification</body></html>`,
			want: true,
		},
		{
			name: "cloudflare challenge phrase",
			body: `This site uses Cloudflare and a challenge must be solved`,
			want: true,
		},
		{
			name: "__cf_chl_tk cookie",
			body: `var __cf_chl_tk = "abc123";`,
			want: true,
		},
		{
			name: "just a moment",
			body: `Just a moment...`,
			want: true,
		},
		{
			name: "checking your browser",
			body: `Checking your browser before accessing the site`,
			want: true,
		},
		{
			name: "cloudflare without challenge",
			body: `Powered by Cloudflare`,
			want: false,
		},
		{
			name: "normal html",
			body: `<html><head><title>Hello</title></head></html>`,
			want: false,
		},
		{
			name: "empty string",
			body: ``,
			want: false,
		},
		{
			name: "case insensitive cf",
			body: `CF-Browser-Verification`,
			want: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ContainsCloudflareChallenge(tt.body)
			if got != tt.want {
				t.Errorf("ContainsCloudflareChallenge(%q) = %v, want %v", tt.body, got, tt.want)
			}
		})
	}
}
