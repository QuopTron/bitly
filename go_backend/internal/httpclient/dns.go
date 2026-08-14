package httpclient

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"time"
)

// DoHResolver resolves hostnames via DNS-over-HTTPS.
type DoHResolver struct {
	client  *http.Client
	baseURL string
}

// NewDoHResolver creates a resolver using Cloudflare's DoH endpoint.
func NewDoHResolver() *DoHResolver {
	return &DoHResolver{
		client:  &http.Client{Timeout: 10 * time.Second},
		baseURL: "https://cloudflare-dns.com/dns-query",
	}
}

// dohResponse represents a DNS-over-HTTPS JSON response.
type dohResponse struct {
	Status   int        `json:"Status"`
	Answer   []dohAnswer `json:"Answer,omitempty"`
}

type dohAnswer struct {
	Name string `json:"name"`
	Type int    `json:"type"`
	Data string `json:"data"`
}

// Resolve returns IP addresses for a hostname via DoH.
func (r *DoHResolver) Resolve(hostname string) ([]net.IP, error) {
	req, err := http.NewRequest("GET", r.baseURL, nil)
	if err != nil {
		return nil, err
	}
	q := req.URL.Query()
	q.Set("name", hostname)
	q.Set("type", "A")
	q.Set("ct", "application/dns-json")
	req.URL.RawQuery = q.Encode()
	req.Header.Set("Accept", "application/dns-json")

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var dnsResp dohResponse
	if err := json.NewDecoder(resp.Body).Decode(&dnsResp); err != nil {
		return nil, err
	}

	if dnsResp.Status != 0 {
		return nil, fmt.Errorf("doh: nxdomain %s", hostname)
	}

	var ips []net.IP
	for _, ans := range dnsResp.Answer {
		if ans.Type == 1 { // A record
			ip := net.ParseIP(ans.Data)
			if ip != nil {
				ips = append(ips, ip)
			}
		}
	}
	if len(ips) == 0 {
		return nil, fmt.Errorf("doh: no A records for %s", hostname)
	}
	return ips, nil
}

// dohClient performs DNS-over-HTTPS queries against Cloudflare 1.1.1.1, but its
// transport dials the fixed IP directly so resolution never depends on the
// on-device local DNS (which is unavailable to Go on Android/LDPlayer).
var dohClient = newDoHClient()

func newDoHClient() *http.Client {
	dialer := &net.Dialer{Timeout: 8 * time.Second, KeepAlive: 30 * time.Second}
	transport := &http.Transport{
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			return dialer.DialContext(ctx, "tcp", "1.1.1.1:443")
		},
		TLSClientConfig: &tls.Config{
			ServerName: "cloudflare-dns.com",
		},
		ForceAttemptHTTP2:  false,
		DisableCompression: true,
		MaxIdleConns:       5,
		IdleConnTimeout:    60 * time.Second,
	}
	return &http.Client{Timeout: 10 * time.Second, Transport: transport}
}

// dohResolve resolves a single hostname to an IPv4 address via DoH.
func dohResolve(ctx context.Context, hostname string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", "https://cloudflare-dns.com/dns-query", nil)
	if err != nil {
		return "", err
	}
	q := req.URL.Query()
	q.Set("name", hostname)
	q.Set("type", "A")
	q.Set("ct", "application/dns-json")
	req.URL.RawQuery = q.Encode()
	req.Header.Set("Accept", "application/dns-json")

	resp, err := dohClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var dnsResp dohResponse
	if err := json.NewDecoder(resp.Body).Decode(&dnsResp); err != nil {
		return "", err
	}
	if dnsResp.Status != 0 {
		return "", fmt.Errorf("doh: nxdomain %s", hostname)
	}
	for _, ans := range dnsResp.Answer {
		if ans.Type == 1 { // A record
			if ip := net.ParseIP(ans.Data); ip != nil {
				return ans.Data, nil
			}
		}
	}
	return "", fmt.Errorf("doh: no A record for %s", hostname)
}

// NewDoHDialContext returns a DialContext that resolves hostnames via
// DNS-over-HTTPS (fixed Cloudflare endpoint, bypassing the on-device resolver)
// and then dials the resolved address. Pass it as an http.Transport's
// DialContext to make that client independent of broken local DNS.
func NewDoHDialContext() func(ctx context.Context, network, addr string) (net.Conn, error) {
	return func(ctx context.Context, network, addr string) (net.Conn, error) {
		host, port, err := net.SplitHostPort(addr)
		if err != nil {
			return nil, err
		}
		if net.ParseIP(host) != nil {
			d := net.Dialer{Timeout: 15 * time.Second}
			return d.DialContext(ctx, network, addr)
		}
		resolved, err := dohResolve(ctx, host)
		if err != nil {
			return nil, err
		}
		d := net.Dialer{Timeout: 15 * time.Second}
		return d.DialContext(ctx, network, net.JoinHostPort(resolved, port))
	}
}
