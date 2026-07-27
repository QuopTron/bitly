package httpclient

import (
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
