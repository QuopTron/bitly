package httpclient

import (
	"context"
	"fmt"
	"net"
	"time"
)

func (dm *DNSManager) Resolve(ctx context.Context, hostname string) ([]net.IP, error) {
	if net.ParseIP(hostname) != nil {
		return []net.IP{net.ParseIP(hostname)}, nil
	}

	// Comprueba la caché
	dm.mutexCache.RLock()
	if entry, ok := dm.almacenCache[hostname]; ok && time.Now().Before(entry.expira) {
		dm.mutexCache.RUnlock()
		if entry.negativo {
			return nil, fmt.Errorf("doh: cached failure for %s", hostname)
		}
		return entry.ips, nil
	}
	dm.mutexCache.RUnlock()

	dm.mutex.Lock()
	allowPrivate := dm.permitirPrivadas
	dm.mutex.Unlock()

	// Try each resolver
	var lastErr error
	for _, resolver := range dm.resolvedores {
		ips, err := dm.resolverVia(ctx, resolver, hostname)
		if err != nil {
			lastErr = err
			continue
		}
		// SSRF guard
		if !allowPrivate {
			filtered := make([]net.IP, 0, len(ips))
			for _, ip := range ips {
				if !esIPPrivada(ip) {
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
		dm.mutexCache.Lock()
		dm.almacenCache[hostname] = &entradaCacheDNS{
			ips:    ips,
			expira: time.Now().Add(2 * time.Minute),
		}
		dm.mutexCache.Unlock()

		return ips, nil
	}

	// All resolvers failed — cache negative (30s)
	dm.mutexCache.Lock()
	dm.almacenCache[hostname] = &entradaCacheDNS{
		negativo: true,
		expira:   time.Now().Add(30 * time.Second),
	}
	dm.mutexCache.Unlock()

	return nil, fmt.Errorf("doh: all resolvers failed for %s: %w", hostname, lastErr)
}

func (dm *DNSManager) resolverVia(ctx context.Context, resolver *resolvedorDoH, hostname string) ([]net.IP, error) {
	// Try JSON API first
	ips, err := dm.resolverJSON(ctx, resolver, hostname)
	if err == nil && len(ips) > 0 {
		return ips, nil
	}

	// Fallback to wire protocol
	return dm.resolverWire(ctx, resolver, hostname)
}
