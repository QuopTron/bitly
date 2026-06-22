//go:build !ios

package httpclient

import (
	"context"
	"crypto/tls"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"

	utls "github.com/refraction-networking/utls"
	"golang.org/x/net/http2"
)

// uTLSTransport uses Chrome TLS fingerprint to bypass Cloudflare challenges.
type uTLSTransport struct {
	dialer *net.Dialer
}

func newUTLSTransport() *uTLSTransport {
	return &uTLSTransport{
		dialer: &net.Dialer{
			Timeout:   30 * time.Second,
			KeepAlive: 30 * time.Second,
		},
	}
}

func (t *uTLSTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	if req.URL.Scheme != "https" {
		return sharedTransport.RoundTrip(req)
	}

	host := req.URL.Hostname()
	port := getPort(req.URL)
	addr := net.JoinHostPort(host, port)

	conn, err := t.dialer.DialContext(req.Context(), "tcp", addr)
	if err != nil {
		return nil, err
	}

	tlsConn := utls.UClient(conn, &utls.Config{
		ServerName: host,
		NextProtos: []string{"h2", "http/1.1"},
	}, utls.HelloChrome_Auto)

	if err := tlsConn.Handshake(); err != nil {
		conn.Close()
		return nil, err
	}

	negotiatedProto := tlsConn.ConnectionState().NegotiatedProtocol

	if negotiatedProto == "h2" {
		h2Transport := &http2.Transport{
			DialTLSContext: func(ctx context.Context, network, addr string, cfg *tls.Config) (net.Conn, error) {
				return tlsConn, nil
			},
			AllowHTTP:          false,
			DisableCompression: false,
		}
		return h2Transport.RoundTrip(req)
	}

	transport := &http.Transport{
		DialTLSContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			return tlsConn, nil
		},
		DisableKeepAlives: true,
	}

	return transport.RoundTrip(req)
}

func getPort(u *url.URL) string {
	if u.Port() != "" {
		return u.Port()
	}
	if u.Scheme == "https" {
		return "443"
	}
	return "80"
}

// CloudflareBypassClient uses Chrome TLS fingerprint to bypass Cloudflare.
var CloudflareBypassClient = &http.Client{
	Transport: newUTLSTransport(),
	Timeout:   DefaultTimeout,
}

// DoWithCloudflareBypass attempts a request normally, falling back to uTLS if Cloudflare detected.
func DoWithCloudflareBypass(req *http.Request) (*http.Response, error) {
	req.Header.Set("User-Agent", UserAgentForURL(req.URL))

	resp, err := DefaultClient.Do(req)
	if err == nil {
		if resp.StatusCode == 403 || resp.StatusCode == 503 {
			body, readErr := io.ReadAll(resp.Body)
			resp.Body.Close()

			if readErr == nil && ContainsCloudflareChallenge(string(body)) {
				reqCopy := req.Clone(req.Context())
				reqCopy.Header.Set("User-Agent", UserAgentForURL(reqCopy.URL))
				return CloudflareBypassClient.Do(reqCopy)
			}
			return &http.Response{
				Status:     resp.Status,
				StatusCode: resp.StatusCode,
				Header:     resp.Header,
				Body:       io.NopCloser(strings.NewReader(string(body))),
			}, nil
		}
		return resp, nil
	}

	errStr := strings.ToLower(err.Error())
	tlsRelated := strings.Contains(errStr, "tls") ||
		strings.Contains(errStr, "handshake") ||
		strings.Contains(errStr, "certificate") ||
		strings.Contains(errStr, "connection reset")

	if tlsRelated {
		reqCopy := req.Clone(req.Context())
		reqCopy.Header.Set("User-Agent", UserAgentForURL(reqCopy.URL))
		return CloudflareBypassClient.Do(reqCopy)
	}

	return nil, err
}
