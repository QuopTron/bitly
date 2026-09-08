package httpclient

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"strings"
)

func (dm *DNSManager) resolverJSON(ctx context.Context, resolver *resolvedorDoH, hostname string) ([]net.IP, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", resolver.urlBase, nil)
	if err != nil {
		return nil, err
	}
	q := req.URL.Query()
	q.Set("name", hostname)
	q.Set("type", "A")
	q.Set("ct", "application/dns-json")
	req.URL.RawQuery = q.Encode()
	req.Header.Set("Accept", "application/dns-json")

	resp, err := resolver.cliente.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var dnsResp struct {
		Status int `json:"Status"`
		Answer []struct {
			Name string `json:"name"`
			Type int    `json:"type"`
			Data string `json:"data"`
		} `json:"Answer,omitempty"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&dnsResp); err != nil {
		return nil, err
	}
	if dnsResp.Status != 0 {
		return nil, fmt.Errorf("doh: status %d for %s", dnsResp.Status, hostname)
	}

	var ips []net.IP
	for _, ans := range dnsResp.Answer {
		if ans.Type == 1 {
			if ip := net.ParseIP(ans.Data); ip != nil {
				ips = append(ips, ip)
			}
		}
	}
	if len(ips) == 0 {
		return nil, fmt.Errorf("doh: no A records for %s", hostname)
	}
	return ips, nil
}

func (dm *DNSManager) resolverWire(ctx context.Context, resolver *resolvedorDoH, hostname string) ([]net.IP, error) {
	query := consultaWireDNS(hostname)
	req, err := http.NewRequestWithContext(ctx, "POST", resolver.urlBase, strings.NewReader(string(query)))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/dns-message")
	req.Header.Set("Accept", "application/dns-message")

	resp, err := resolver.cliente.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var buf [512]byte
	n, err := resp.Body.Read(buf[:])
	if err != nil && n == 0 {
		return nil, err
	}
	return parsearRespuestaWire(buf[:n])
}
