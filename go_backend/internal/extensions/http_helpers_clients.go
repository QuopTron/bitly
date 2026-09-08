package extensions

import (
	"context"
	"crypto/tls"
	"net"
	"net/http"
	"net/http/cookiejar"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
	"golang.org/x/net/http2"
)

var (
	extHTTPClientOnce sync.Once
	extHTTPClient     *http.Client
)

// YouTube domains that require uTLS fingerprinting to avoid 403 bot-gate.
var youtubeHosts = map[string]bool{
	"www.youtube.com":   true,
	"youtube.com":       true,
	"ytimg.com":         true,
	"googlevideo.com":   true,
	"youtu.be":          true,
	"music.youtube.com": true,
}

func esHostYouTube(url string) bool {
	for host := range youtubeHosts {
		if strings.Contains(url, host) {
			return true
		}
	}
	return false
}

// isGooglevideoHost reports whether [url] points at YouTube's media CDN
// (rr*.googlevideo.com/videoplayback). These carry a signed URL, are served
// over plain HTTP/1.1, and are NOT bot-gated like the InnerTube API — they
// must use the standard DoH client instead of the uTLS/HTTP2 one (whose
// HTTP2 framing breaks on the CDN: "http2: frame too large").
func esHostGooglevideo(url string) bool {
	return strings.Contains(url, "googlevideo.com")
}

// extHTTPClientFor returns the shared, lazily-initialized extension HTTP
// client with a persistent cookie jar.
func clienteHTTPExtPara() *http.Client {
	extHTTPClientOnce.Do(func() {
		jar, _ := cookiejar.New(nil)
		transport := &http.Transport{
			DialContext:         httpclient.NewDoHDialContext(),
			ForceAttemptHTTP2:   true,
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 10,
			IdleConnTimeout:     90 * time.Second,
			TLSHandshakeTimeout: 10 * time.Second,
			DisableCompression:  true,
		}
		extHTTPClient = &http.Client{
			Timeout:   30 * time.Second,
			Transport: transport,
			Jar:       jar,
		}
	})
	return extHTTPClient
}

// ytHTTPClient is a separate HTTP client for YouTube/InnerTube requests that
// usa uTLS fingerprinting a mimic un real Chrome navegador TLS handshake.// YouTube bot-gates IPs with a Go TLS fingerprint → 403; uTLS solves this.
var (
	ytHTTPClientOnce sync.Once
	ytHTTPClient     *http.Client
)

func ytHTTPClientFor() *http.Client {
	ytHTTPClientOnce.Do(func() {
		jar, _ := cookiejar.New(nil)
		// uTLS dialer mimics Chrome's TLS fingerprint to bypass YouTube bot
		// detection, resolving via DoH so Android's system resolver never
		// fails the dial.
		dialFn := httpclient.NewUTLSDialer(httpclient.FingerprintChrome)
		// YouTube's servers negotiate HTTP/2 over ALPN EVEN when the client
		// only offers http/1.1 (verified: music.youtube.com answers h2), so a
		// plain http/1.1 transport breaks on the h2 frames with "malformed
		// HTTP response". Speak HTTP/2 over the uTLS connection instead.
		tr := &http2.Transport{
			DialTLSContext: func(ctx context.Context, network, addr string, _ *tls.Config) (net.Conn, error) {
				return dialFn(network, addr)
			},
		}
		ytHTTPClient = &http.Client{
			Timeout:   30 * time.Second,
			Transport: tr,
			Jar:       jar,
		}
	})
	return ytHTTPClient
}

// doHTTPCompat returns the old-style {status, body, headers} object.
