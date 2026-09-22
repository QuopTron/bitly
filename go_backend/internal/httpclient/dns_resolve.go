package httpclient

import (
	"context"
	"fmt"
	"net"
	"time"
)

// Resolve devuelve las IPs de un hostname por DoH, con caché y single-flight.
//
// El single-flight es lo que faltaba: cada dial llamaba a Resolve y, si la
// caché estaba fría, lanzaba su propia consulta DoH (1–2 HTTPS a Cloudflare o
// Google). Una búsqueda hace muchas peticiones al MISMO host, así que se
// repetían N consultas idénticas en paralelo — latencia extra, conexiones de
// más y RAM de más. Ahora la primera consulta del host se comparte: las demás
// esperan su resultado.
func (dm *DNSManager) Resolve(ctx context.Context, hostname string) ([]net.IP, error) {
	if ip := net.ParseIP(hostname); ip != nil {
		return []net.IP{ip}, nil
	}

	// Comprueba la caché
	dm.mutexCache.RLock()
	entry, ok := dm.almacenCache[hostname]
	dm.mutexCache.RUnlock()
	if ok && time.Now().Before(entry.expira) {
		if entry.negativo {
			return nil, fmt.Errorf("doh: cached failure for %s", hostname)
		}
		return entry.ips, nil
	}

	// Single-flight: apuntarse a la consulta en curso o crearla.
	dm.mutexCache.Lock()
	if dm.enVuelo == nil {
		dm.enVuelo = make(map[string]*vueloDNS)
	}
	if enCurso, hay := dm.enVuelo[hostname]; hay {
		dm.mutexCache.Unlock()
		select {
		case <-enCurso.hecho:
			return enCurso.ips, enCurso.err
		case <-ctx.Done():
			// El que espera sí puede rendirse: el resultado compartido sigue en
			// camino para los demás.
			return nil, ctx.Err()
		}
	}
	vuelo := &vueloDNS{hecho: make(chan struct{})}
	dm.enVuelo[hostname] = vuelo
	dm.mutexCache.Unlock()

	ips, err := dm.resolverDoH(ctx, hostname)

	vuelo.ips, vuelo.err = ips, err
	close(vuelo.hecho)
	dm.mutexCache.Lock()
	delete(dm.enVuelo, hostname)
	dm.mutexCache.Unlock()

	return ips, err
}

// resolverDoH hace la consulta real (resolvedores en orden + guarda SSRF) y
// escribe la caché. Es la parte que ejecuta solo el líder del single-flight.
func (dm *DNSManager) resolverDoH(ctx context.Context, hostname string) ([]net.IP, error) {
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

	// All resolvers failed. Un fallo por cancelación del llamador NO se cachea:
	// no dice nada del host y dejaría a ese host sin resolver durante 30 s para
	// todas las peticiones siguientes.
	if ctx.Err() != nil {
		return nil, fmt.Errorf("doh: %s: %w", hostname, ctx.Err())
	}

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
