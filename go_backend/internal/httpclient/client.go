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
	Timeout             time.Duration
	KeepAlive           time.Duration
	MaxIdleConns        int
	MaxIdleConnsPerHost int
	DisableKeepAlive    bool
	FollowRedirects     bool
	InsecureSkipVerify  bool
	ProxyURL            string // optional HTTP/SOCKS proxy URL

	// TLSHandshakeTimeout y ResponseHeaderTimeout acotan las dos esperas que
	// antes quedaban sin techo: un servidor que acepta el TCP/TLS y luego no
	// contesta nada dejaba al llamador esperando el Timeout completo del
	// cliente (30 s) o el global de la búsqueda, y eso se ve como "la búsqueda
	// se quedó cargando". Con cero, se usa el valor por defecto.
	TLSHandshakeTimeout   time.Duration
	ResponseHeaderTimeout time.Duration
}

// DefaultConfig returns a sensible default configuration.
func DefaultConfig() Config {
	return Config{
		Timeout:   30 * time.Second,
		KeepAlive: 30 * time.Second,
		// 100 conexiones ociosas en total y 16 por host. El valor por defecto de
		// Go es 2 por host, y una búsqueda dispara varias llamadas simultáneas
		// al MISMO host (catálogo + detalle + player), así que con 2 se reabría
		// TLS en medio de la búsqueda.
		MaxIdleConns:          100,
		MaxIdleConnsPerHost:   16,
		TLSHandshakeTimeout:   10 * time.Second,
		ResponseHeaderTimeout: 15 * time.Second,
		FollowRedirects:       true,
		InsecureSkipVerify:    false,
	}
}

// NewTransport creates an http.Transport from the given config.
// If dialFn is provided, it replaces the default TCP dialer (used for utls).
func NewTransport(cfg Config, dialFn func(network, addr string) (net.Conn, error)) *http.Transport {
	tlsTimeout := cfg.TLSHandshakeTimeout
	if tlsTimeout <= 0 {
		tlsTimeout = 10 * time.Second
	}
	headerTimeout := cfg.ResponseHeaderTimeout
	if headerTimeout <= 0 {
		headerTimeout = 15 * time.Second
	}
	transport := &http.Transport{
		MaxIdleConns:        cfg.MaxIdleConns,
		MaxIdleConnsPerHost: cfg.MaxIdleConnsPerHost,
		IdleConnTimeout:     90 * time.Second,
		DisableKeepAlives:   cfg.DisableKeepAlive,
		ForceAttemptHTTP2:   false,
		// Estas dos esperas antes no tenían techo: la conexión podía quedar
		// colgada en el handshake TLS o esperando una cabecera que nunca llega.
		TLSHandshakeTimeout:   tlsTimeout,
		ResponseHeaderTimeout: headerTimeout,
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
		Timeout: cfg.Timeout,
		// ContarTransporte: toda petición de este cliente queda en el
		// diagnóstico de red (conteo.go) sin tocar la respuesta.
		Transport: ContarTransporte(NewTransport(cfg, nil)),
	}
}

// NewClientWithUTLS creates an http.Client that uses utls for TLS fingerprinting.
func NewClientWithUTLS(cfg Config, fingerprint string) *http.Client {
	dialFn := NewUTLSDialer(fingerprint)
	transport := NewTransport(cfg, dialFn)
	transport.TLSClientConfig = nil // utls handles TLS, disable stdlib TLS
	return &http.Client{
		Timeout:   cfg.Timeout,
		Transport: ContarTransporte(transport),
	}
}
