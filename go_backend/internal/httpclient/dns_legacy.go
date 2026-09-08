package httpclient

import (
	"context"
	"net"
	"net/http"
	"time"
)

type DoHResolver struct {
	cliente *http.Client
	urlBase string
}

func NewDoHResolver() *DoHResolver {
	return &DoHResolver{
		cliente: &http.Client{Timeout: 10 * time.Second},
		urlBase: "https://cloudflare-dns.com/dns-query",
	}
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
