package extensions

import (
	"net/http"
	"sync/atomic"
	"testing"
)

// mockTransport counts bootstrap requests so we can assert the cooldown guard
// prevents re-hammering a failing gateway.
type mockTransport struct {
	calls int64
	code  int
}

func (m *mockTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	atomic.AddInt64(&m.calls, 1)
	return &http.Response{
		StatusCode: m.code,
		Header:     make(http.Header),
		Body:       http.NoBody,
		Request:    req,
	}, nil
}

func TestBootstrapGuardCooldownOnFailure(t *testing.T) {
	tr := &mockTransport{code: http.StatusTooManyRequests}
	client := &http.Client{Transport: tr}
	state := &SignedSessionState{}
	record := &signedSessionRecord{InstallID: "test-install"}
	cfg := signedSessionConfigWithDefaults(&SignedSessionConfig{Namespace: "deezer", BaseURL: "https://example.com", AppVersion: "ext-1.0"})

	// First attempt fails with 429.
	_, err1 := state.bootstrapWithGuard(client, cfg, record)
	if err1 == nil {
		t.Fatalf("expected bootstrap failure on 429, got nil")
	}

	// Immediately retrying must be served from cooldown cache and NOT hit the
	// transport again.
	_, err2 := state.bootstrapWithGuard(client, cfg, record)
	if err2 == nil || err2.Error() != err1.Error() {
		t.Fatalf("expected cached error during cooldown, got %v", err2)
	}
	if got := atomic.LoadInt64(&tr.calls); got != 1 {
		t.Fatalf("expected 1 transport call (cached by cooldown), got %d", got)
	}
}