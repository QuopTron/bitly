package httpclient

import (
	"context"
	"io"
	"net/http"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestBreakerParsAtTwoGateway5xx(t *testing.T) {
	// Fresh state so prior tests can't pollute this one.
	hostBreaker.mu.Lock()
	hostBreaker.entries = map[string]*hostBreakerEntry{}
	hostBreaker.mu.Unlock()

	url := "https://api.zarz.moe/v2/some/endpoint"
	BreakerRecord(url, 522, nil)
	if BreakerBlocked(url) {
		t.Fatal("first 522 must not park the host yet")
	}
	BreakerRecord(url, 522, nil)
	if !BreakerBlocked(url) {
		t.Fatal("second 522 within the window must park the host")
	}
	// While parked the transport short-circuits, so a real response can only
	// arrive after the window expires — backdate it and confirm a healthy
	// reply clears the counters and unparks the host.
	hostBreaker.mu.Lock()
	e := hostBreaker.entries["api.zarz.moe"]
	if e == nil {
		t.Fatal("expected a breaker entry")
	}
	e.parkedUntil = time.Now().Add(-time.Second)
	hostBreaker.mu.Unlock()
	BreakerRecord(url, 200, nil)
	if BreakerBlocked(url) {
		t.Fatal("a healthy 200 after the window must clear the parked state")
	}
}

func TestBreakerIgnoresDefinitiveErrors(t *testing.T) {
	hostBreaker.mu.Lock()
	hostBreaker.entries = map[string]*hostBreakerEntry{}
	hostBreaker.mu.Unlock()

	// 429 / 404 prove the origin is reachable — never park on them.
	for i := 0; i < 5; i++ {
		BreakerRecord("https://api.zarz.moe/x", 429, nil)
		BreakerRecord("https://api.zarz.moe/x", 404, nil)
	}
	if BreakerBlocked("https://api.zarz.moe/x") {
		t.Fatal("4xx responses must never park the host")
	}
}

func TestBreakerParsAtThreeNetworkHangs(t *testing.T) {
	hostBreaker.mu.Lock()
	hostBreaker.entries = map[string]*hostBreakerEntry{}
	hostBreaker.mu.Unlock()

	url := "https://slow.example/api"
	BreakerRecord(url, 0, context.DeadlineExceeded)
	BreakerRecord(url, 0, context.DeadlineExceeded)
	if BreakerBlocked(url) {
		t.Fatal("two hangs must not park (egress blips are common)")
	}
	BreakerRecord(url, 0, context.DeadlineExceeded)
	if !BreakerBlocked(url) {
		t.Fatal("three consecutive hangs must park the host")
	}
}

func TestBreakerResetsAfterWindow(t *testing.T) {
	hostBreaker.mu.Lock()
	hostBreaker.entries = map[string]*hostBreakerEntry{}
	hostBreaker.mu.Unlock()

	url := "https://api.zarz.moe/x"
	// Backdate the first failure beyond the window so the second failure is a
	// fresh window and must NOT park.
	BreakerRecord(url, 522, nil)
	hostBreaker.mu.Lock()
	e := hostBreaker.entries["api.zarz.moe"]
	if e != nil {
		e.fiveXXAt = time.Now().Add(-hostBreakerWindow - time.Second)
	}
	hostBreaker.mu.Unlock()
	BreakerRecord(url, 522, nil)
	if BreakerBlocked(url) {
		t.Fatal("failures older than the window must not accumulate")
	}
}

func TestBreakerTransportShortCircuitsParkedHost(t *testing.T) {
	hostBreaker.mu.Lock()
	hostBreaker.entries = map[string]*hostBreakerEntry{}
	hostBreaker.mu.Unlock()

	var calls int32
	inner := roundTripFunc(func(*http.Request) (*http.Response, error) {
		atomic.AddInt32(&calls, 1)
		return &http.Response{StatusCode: 522, Status: "522", Header: http.Header{}, Body: io.NopCloser(strings.NewReader(""))}, nil
	})
	tr := NewBreakerTransport(inner).(*breakerTransport)

	req, _ := http.NewRequest("GET", "https://api.zarz.moe/v2/dl/x", nil)
	resp, err := tr.RoundTrip(req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != 522 {
		t.Fatalf("expected real 522, got %d", resp.StatusCode)
	}
	// Second response parks the host; third call must NOT reach the network.
	if _, err := tr.RoundTrip(req); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, err := tr.RoundTrip(req); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got := atomic.LoadInt32(&calls); got != 2 {
		t.Fatalf("expected 2 network calls (2nd parked the host), got %d", got)
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
