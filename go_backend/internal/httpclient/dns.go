package httpclient

import (
	"context"
	"crypto/tls"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

// DNSManager manages DoH resolution with multiple resolvers, caching, and SSRF protection.
type DNSManager struct {
	resolvers    []*dohResolver
	cache        map[string]*dnsCacheEntry
	cacheMu      sync.RWMutex
	allowPrivate bool
	mu           sync.Mutex
}

type dohResolver struct {
	client  *http.Client
	baseURL string
	name    string
}

type dnsCacheEntry struct {
	ips      []net.IP
	expires  time.Time
	negative bool
}

var (
	globalDNS     *DNSManager
	globalDNSOnce sync.Once
)

// GetDNSManager returns the singleton DNS manager.
func GetDNSManager() *DNSManager {
	globalDNSOnce.Do(func() {
		globalDNS = &DNSManager{
			resolvers: []*dohResolver{
				{name: "Cloudflare", baseURL: "https://cloudflare-dns.com/dns-query"},
				{name: "Google", baseURL: "https://dns.google/resolve"},
			},
			cache: make(map[string]*dnsCacheEntry),
		}
		for _, r := range globalDNS.resolvers {
			r.client = newDoHHTTPClient(r.baseURL)
		}
	})
	return globalDNS
}

func newDoHHTTPClient(upstream string) *http.Client {
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
	dm.mu.Lock()
	defer dm.mu.Unlock()
	dm.allowPrivate = allow
}

func isPrivateIP(ip net.IP) bool {
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
func (dm *DNSManager) Resolve(ctx context.Context, hostname string) ([]net.IP, error) {
	if net.ParseIP(hostname) != nil {
		return []net.IP{net.ParseIP(hostname)}, nil
	}

	// Check cache
	dm.cacheMu.RLock()
	if entry, ok := dm.cache[hostname]; ok && time.Now().Before(entry.expires) {
		dm.cacheMu.RUnlock()
		if entry.negative {
			return nil, fmt.Errorf("doh: cached failure for %s", hostname)
		}
		return entry.ips, nil
	}
	dm.cacheMu.RUnlock()

	dm.mu.Lock()
	allowPrivate := dm.allowPrivate
	dm.mu.Unlock()

	// Try each resolver
	var lastErr error
	for _, resolver := range dm.resolvers {
		ips, err := dm.resolveVia(ctx, resolver, hostname)
		if err != nil {
			lastErr = err
			continue
		}
		// SSRF guard
		if !allowPrivate {
			filtered := make([]net.IP, 0, len(ips))
			for _, ip := range ips {
				if !isPrivateIP(ip) {
					filtered = append(filtered, ip)
				}
			}
			if len(filtered) == 0 {
				lastErr = fmt.Errorf("doh: all resolved IPs are private for %s", hostname)
				continue
			}
			ips = filtered
		}

		// Cache positive result (1-5 min TTL)
		dm.cacheMu.Lock()
		dm.cache[hostname] = &dnsCacheEntry{
			ips:     ips,
			expires: time.Now().Add(2 * time.Minute),
		}
		dm.cacheMu.Unlock()

		return ips, nil
	}

	// All resolvers failed — cache negative (30s)
	dm.cacheMu.Lock()
	dm.cache[hostname] = &dnsCacheEntry{
		negative: true,
		expires:  time.Now().Add(30 * time.Second),
	}
	dm.cacheMu.Unlock()

	return nil, fmt.Errorf("doh: all resolvers failed for %s: %w", hostname, lastErr)
}

func (dm *DNSManager) resolveVia(ctx context.Context, resolver *dohResolver, hostname string) ([]net.IP, error) {
	// Try JSON API first
	ips, err := dm.resolveJSON(ctx, resolver, hostname)
	if err == nil && len(ips) > 0 {
		return ips, nil
	}

	// Fallback to wire protocol
	return dm.resolveWire(ctx, resolver, hostname)
}

func (dm *DNSManager) resolveJSON(ctx context.Context, resolver *dohResolver, hostname string) ([]net.IP, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", resolver.baseURL, nil)
	if err != nil {
		return nil, err
	}
	q := req.URL.Query()
	q.Set("name", hostname)
	q.Set("type", "A")
	q.Set("ct", "application/dns-json")
	req.URL.RawQuery = q.Encode()
	req.Header.Set("Accept", "application/dns-json")

	resp, err := resolver.client.Do(req)
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

func (dm *DNSManager) resolveWire(ctx context.Context, resolver *dohResolver, hostname string) ([]net.IP, error) {
	query := dnsWireQuery(hostname)
	req, err := http.NewRequestWithContext(ctx, "POST", resolver.baseURL, strings.NewReader(string(query)))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/dns-message")
	req.Header.Set("Accept", "application/dns-message")

	resp, err := resolver.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var buf [512]byte
	n, err := resp.Body.Read(buf[:])
	if err != nil && n == 0 {
		return nil, err
	}
	return parseDNSWireResponse(buf[:n])
}

func dnsWireQuery(hostname string) []byte {
	header := make([]byte, 12)
	binary.BigEndian.PutUint16(header[0:2], 0xABCD)
	binary.BigEndian.PutUint16(header[2:4], 0x0100)
	binary.BigEndian.PutUint16(header[4:6], 1)

	var qname []byte
	for _, label := range strings.Split(hostname, ".") {
		qname = append(qname, byte(len(label)))
		qname = append(qname, []byte(label)...)
	}
	qname = append(qname, 0)

	question := make([]byte, 0, len(qname)+4)
	question = append(question, qname...)
	question = append(question, 0, 1) // QTYPE = A
	question = append(question, 0, 1) // QCLASS = IN

	return append(header, question...)
}

func parseDNSWireResponse(data []byte) ([]net.IP, error) {
	if len(data) < 12 {
		return nil, fmt.Errorf("dns: response too short")
	}
	ancount := int(binary.BigEndian.Uint16(data[6:8]))
	if ancount == 0 {
		return nil, fmt.Errorf("dns: no A records")
	}
	offset := 12
	for offset < len(data) {
		if data[offset] == 0 {
			offset++
			break
		}
		if data[offset]&0xC0 == 0xC0 {
			offset += 2
			break
		}
		offset += int(data[offset]) + 1
	}
	offset += 4

	var ips []net.IP
	for i := 0; i < ancount && offset < len(data); i++ {
		if offset < len(data) && data[offset]&0xC0 == 0xC0 {
			offset += 2
		} else {
			for offset < len(data) && data[offset] != 0 {
				offset += int(data[offset]) + 1
			}
			offset++
		}
		if offset+10 > len(data) {
			break
		}
		rType := binary.BigEndian.Uint16(data[offset : offset+2])
		offset += 2
		offset += 2
		offset += 4
		rdLength := int(binary.BigEndian.Uint16(data[offset : offset+2]))
		offset += 2
		if rType == 1 && rdLength == 4 && offset+4 <= len(data) {
			ips = append(ips, net.IP(data[offset:offset+4]))
		}
		offset += rdLength
	}
	if len(ips) == 0 {
		return nil, fmt.Errorf("dns: no A records parsed")
	}
	return ips, nil
}

// ClearCache removes all cached DNS entries.
func (dm *DNSManager) ClearCache() {
	dm.cacheMu.Lock()
	defer dm.cacheMu.Unlock()
	dm.cache = make(map[string]*dnsCacheEntry)
}

// ═══════════════════════════════════════════════════════════════════════
// Legacy API — backward-compatible functions
// ═══════════════════════════════════════════════════════════════════════

// DoHResolver resolves hostnames via DNS-over-HTTPS (legacy API).
type DoHResolver struct {
	client  *http.Client
	baseURL string
}

func NewDoHResolver() *DoHResolver {
	return &DoHResolver{
		client:  &http.Client{Timeout: 10 * time.Second},
		baseURL: "https://cloudflare-dns.com/dns-query",
	}
}

type dohResponse struct {
	Status int         `json:"Status"`
	Answer []dohAnswer `json:"Answer,omitempty"`
}

type dohAnswer struct {
	Name string `json:"name"`
	Type int    `json:"type"`
	Data string `json:"data"`
}

func (r *DoHResolver) Resolve(hostname string) ([]net.IP, error) {
	dm := GetDNSManager()
	return dm.Resolve(context.Background(), hostname)
}

var dohClient = func() *http.Client {
	dialer := &net.Dialer{Timeout: 8 * time.Second, KeepAlive: 30 * time.Second}
	transport := &http.Transport{
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			return dialer.DialContext(ctx, "tcp", "1.1.1.1:443")
		},
		TLSClientConfig:    &tls.Config{ServerName: "cloudflare-dns.com"},
		ForceAttemptHTTP2:  false,
		DisableCompression: true,
		MaxIdleConns:       5,
		IdleConnTimeout:    60 * time.Second,
	}
	return &http.Client{Timeout: 10 * time.Second, Transport: transport}
}()

func dohResolve(ctx context.Context, hostname string) (string, error) {
	dm := GetDNSManager()
	ips, err := dm.Resolve(ctx, hostname)
	if err != nil {
		return "", err
	}
	return ips[0].String(), nil
}

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
		dm := GetDNSManager()
		ips, err := dm.Resolve(ctx, host)
		if err != nil {
			return nil, err
		}
		d := net.Dialer{Timeout: 15 * time.Second}
		return d.DialContext(ctx, network, net.JoinHostPort(ips[0].String(), port))
	}
}

// ClearDNSCache clears the global DNS cache (callable from exports).
func ClearDNSCache() {
	GetDNSManager().ClearCache()
}
