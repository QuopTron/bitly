package httpclient

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"strings"
	"time"
)

func GetDNSManager() *DNSManager {
	onceDNSGlobal.Do(func() {
		dnsGlobal = &DNSManager{
			resolvedores: []*resolvedorDoH{
				{nombre: "Cloudflare", urlBase: "https://cloudflare-dns.com/dns-query"},
				{nombre: "Google", urlBase: "https://dns.google/resolve"},
			},
			almacenCache: make(map[string]*entradaCacheDNS),
		}
		for _, r := range dnsGlobal.resolvedores {
			r.cliente = nuevoClienteHTTPDoH(r.urlBase)
		}
	})
	return dnsGlobal
}

func nuevoClienteHTTPDoH(upstream string) *http.Client {
	host := ""
	if u, err := fmt.Sscanf(upstream, "https://%s", &host); err == nil || u > 0 {
		host = strings.TrimSuffix(host, "/dns-query")
		host = strings.TrimSuffix(host, "/resolve")
	}
	dialIP := "1.1.1.1:443"
	if strings.Contains(host, "google") {
		dialIP = "8.8.8.8:443"
	}
	dialer := &net.Dialer{Timeout: 8 * time.Second, KeepAlive: 30 * time.Second}
	transport := &http.Transport{
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			return dialer.DialContext(ctx, "tcp", dialIP)
		},
		TLSClientConfig:       &tls.Config{ServerName: host},
		ForceAttemptHTTP2:     false,
		DisableCompression:    true,
		MaxIdleConns:          5,
		IdleConnTimeout:       60 * time.Second,
		ResponseHeaderTimeout: 10 * time.Second,
	}
	return &http.Client{Timeout: 15 * time.Second, Transport: transport}
}

// SetAllowPrivateIPs enables/disables SSRF guard for private IPs.
func (dm *DNSManager) SetAllowPrivateIPs(allow bool) {
	dm.mutex.Lock()
	defer dm.mutex.Unlock()
	dm.permitirPrivadas = allow
}

func esIPPrivada(ip net.IP) bool {
	if ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() {
		return true
	}
	if ip4 := ip.To4(); ip4 != nil {
		return ip4[0] == 10 ||
			(ip4[0] == 172 && ip4[1] >= 16 && ip4[1] <= 31) ||
			(ip4[0] == 192 && ip4[1] == 168) ||
			ip4[0] == 0
	}
	return false
}

// Resolve returns IP addresses for a hostname via DoH with multi-resolver fallback.
