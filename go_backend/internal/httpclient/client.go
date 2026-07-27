// Package httpclient provides configurable HTTP clients with advanced features:
// TLS fingerprinting (utls), Cloudflare bypass, rate limiting, retry with backoff,
// user-agent rotation, DNS-over-HTTPS, and proxy rotation.
package httpclient

import (
	"context"
	"crypto/tls"
	"net"
	"net/http"
	"net/url"
	"time"
)

// Config defines transport-level tuning for HTTP clients.
type Config struct {
	Timeout              time.Duration
	KeepAlive            time.Duration
	MaxIdleConns         int
	MaxIdleConnsPerHost  int
	DisableKeepAlive     bool
	FollowRedirects      bool
	InsecureSkipVerify   bool
	ProxyURL             string // optional HTTP/SOCKS proxy URL
}

// DefaultConfig returns a sensible default configuration.
func DefaultConfig() Config {
	return Config{
		Timeout:             30 * time.Second,
		KeepAlive:           30 * time.Second,
		MaxIdleConns:        100,
		MaxIdleConnsPerHost: 10,
		FollowRedirects:     true,
		InsecureSkipVerify:  false,
	}
}

// NewTransport creates an http.Transport from the given config.
// If dialFn is provided, it replaces the default TCP dialer (used for utls).
func NewTransport(cfg Config, dialFn func(network, addr string) (net.Conn, error)) *http.Transport {
	transport := &http.Transport{
		MaxIdleConns:        cfg.MaxIdleConns,
		MaxIdleConnsPerHost: cfg.MaxIdleConnsPerHost,
		IdleConnTimeout:     90 * time.Second,
		DisableKeepAlives:   cfg.DisableKeepAlive,
		ForceAttemptHTTP2:   false,
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: cfg.InsecureSkipVerify,
		},
	}
	if dialFn != nil {
		transport.DialTLSContext = func(_ context.Context, network, addr string) (net.Conn, error) {
			return dialFn(network, addr)
		}
	} else {
		transport.DialContext = (&net.Dialer{
			Timeout:   cfg.Timeout,
			KeepAlive: cfg.KeepAlive,
		}).DialContext
	}
	if cfg.ProxyURL != "" {
		if proxyURL, err := url.Parse(cfg.ProxyURL); err == nil {
			transport.Proxy = http.ProxyURL(proxyURL)
		}
	}
	return transport
}

// NewClient creates a standard http.Client from the config with a plain TCP dialer.
func NewClient(cfg Config) *http.Client {
	return &http.Client{
		Timeout:   cfg.Timeout,
		Transport: NewTransport(cfg, nil),
	}
}

// NewClientWithUTLS creates an http.Client that uses utls for TLS fingerprinting.
func NewClientWithUTLS(cfg Config, fingerprint string) *http.Client {
	dialFn := NewUTLSDialer(fingerprint)
	transport := NewTransport(cfg, dialFn)
	transport.TLSClientConfig = nil // utls handles TLS, disable stdlib TLS
	return &http.Client{
		Timeout:   cfg.Timeout,
		Transport: transport,
	}
}
