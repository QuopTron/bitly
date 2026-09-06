// Host-level circuit breaker for dead gateway endpoints.
//
// Several providers depend on third-party gateways (api.zarz.moe for deezer /
// qobuz / tidal / amazon resolutions) that sit behind Cloudflare. When such an
// origin goes down, Cloudflare answers every request with a gateway 5xx (522 /
// 524 / 502 / 504...) — but only AFTER trying the origin, which can take ~10s
// per request. Providers that retry across qualities, formats or sources then
// burn many seconds per track on a host that is deterministically dead, and a
// network timeout (origin hangs, no Cloudflare reply) burns the full client
// timeout (20-30s) instead.
//
// This breaker parks a host for a short window after it fails repeatedly, so
// later requests to the same host fail fast (a synthetic HTTP 522, no network
// I/O) instead of waiting out the timeout each time. Any definitive server
// reply (2xx/3xx/4xx, including 429) proves the origin is reachable again and
// clears the failure counters immediately.
package httpclient

import (
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

const (
	// hostBreakerMax5xx is how many gateway 5xx responses inside the window
	// park the host. Two is enough: the first proves the origin is down, the
	// second confirms it wasn't a one-off blip.
	hostBreakerMax5xx = 2
	// hostBreakerMaxHang is how many consecutive network-level failures
	// (timeouts / TLS / dial) inside the window park the host. Higher than
	// the 5xx threshold because transient egress blips are common and must
	// not blacklist a healthy host.
	hostBreakerMaxHang = 3
	// hostBreakerWindow is how long consecutive failures must span to count
	// as the same outage.
	hostBreakerWindow = 30 * time.Second
	// hostBreakerParkTime is how long a parked host is skipped before it is
	// allowed one real request again (recovered origin is reused fast).
	hostBreakerParkTime = 90 * time.Second
)

// hostBreakerEntry tracks the recent failure history of a single host.
type hostBreakerEntry struct {
	fiveXX      int       // gateway 5xx responses in the window
	fiveXXAt    time.Time // time of the latest 5xx
	hangs       int       // network-level failures in the window
	hangsAt     time.Time // time of the latest hang
	parkedUntil time.Time // while now < parkedUntil, requests are short-circuited
}

var hostBreaker = &hostBreakerState{entries: map[string]*hostBreakerEntry{}}

type hostBreakerState struct {
	mu      sync.Mutex
	entries map[string]*hostBreakerEntry
}

func hostOf(rawURL string) string {
	if rawURL == "" {
		return ""
	}
	if u, err := url.Parse(rawURL); err == nil && u.Hostname() != "" {
		return strings.ToLower(u.Hostname())
	}
	return ""
}

// BreakerBlocked reports whether [rawURL]'s host is currently parked and its
// request should fail fast without touching the network.
func BreakerBlocked(rawURL string) bool {
	host := hostOf(rawURL)
	if host == "" {
		return false
	}
	hostBreaker.mu.Lock()
	defer hostBreaker.mu.Unlock()
	e := hostBreaker.entries[host]
	return e != nil && time.Now().Before(e.parkedUntil)
}

// isGateway5xx reports whether [code] is a gateway/origin error — Cloudflare
// 52x plus the common 500/502/503/504. These mean the origin (not the edge) is
// down, and retrying immediately will just wait for the same failure again.
func isGateway5xx(code int) bool {
	if code == 500 || code == 502 || code == 503 || code == 504 {
		return true
	}
	return code >= 520 && code <= 527
}

// BreakerRecord feeds the outcome of one request to the breaker. [statusCode]
// 0 with a non-nil [err] is a network-level failure (timeout/hang/TLS); a
// non-zero [statusCode] with nil [err] is a definitive server reply.
func BreakerRecord(rawURL string, statusCode int, err error) {
	host := hostOf(rawURL)
	if host == "" {
		return
	}
	hostBreaker.mu.Lock()
	defer hostBreaker.mu.Unlock()
	e := hostBreaker.entries[host]
	if e == nil {
		e = &hostBreakerEntry{}
		hostBreaker.entries[host] = e
	}
	now := time.Now()
	if err != nil {
		// Network-level failure: only counts toward the (higher) hang
		// threshold so a flaky egress IP never parks a healthy host on two
		// quick blips.
		if now.Sub(e.hangsAt) > hostBreakerWindow {
			e.hangs = 0
		}
		e.hangs++
		e.hangsAt = now
		if e.hangs >= hostBreakerMaxHang {
			e.parkedUntil = now.Add(hostBreakerParkTime)
			e.hangs = 0
			e.fiveXX = 0
		}
		return
	}
	if isGateway5xx(statusCode) {
		if now.Sub(e.fiveXXAt) > hostBreakerWindow {
			e.fiveXX = 0
		}
		e.fiveXX++
		e.fiveXXAt = now
		if e.fiveXX >= hostBreakerMax5xx {
			e.parkedUntil = now.Add(hostBreakerParkTime)
			e.fiveXX = 0
			e.hangs = 0
		}
		return
	}
	// Definitive server reply (2xx/3xx/4xx, including 429): the origin is
	// reachable, so whatever 5xxes happened before were transient.
	e.fiveXX = 0
	e.hangs = 0
}

// NewBreakerTransport wraps [inner] with the shared host breaker. While a host
// is parked its requests return a synthetic HTTP 522 without network I/O, so
// callers see a fast, definitive failure instead of waiting out a timeout.
func NewBreakerTransport(inner http.RoundTripper) http.RoundTripper {
	if inner == nil {
		inner = http.DefaultTransport
	}
	return &breakerTransport{inner: inner}
}

type breakerTransport struct {
	inner http.RoundTripper
}

func (t *breakerTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	raw := ""
	if req != nil && req.URL != nil {
		raw = req.URL.String()
	}
	if BreakerBlocked(raw) {
		return SyntheticGatewayResponse(req), nil
	}
	resp, err := t.inner.RoundTrip(req)
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
