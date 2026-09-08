package httpclient

import (
	"time"
)

func esGateway5xx(code int) bool {
	if code == 500 || code == 502 || code == 503 || code == 504 {
		return true
	}
	return code >= 520 && code <= 527
}

// BreakerRecord feeds the outcome of one request to the breaker. [statusCode]
// 0 with a non-nil [err] is a network-level failure (timeout/hang/TLS); a
// non-zero [statusCode] with nil [err] is a definitive server reply.
func BreakerRecord(rawURL string, statusCode int, err error) {
	host := hostDe(rawURL)
	if host == "" {
		return
	}
	breakerHosts.mutex.Lock()
	defer breakerHosts.mutex.Unlock()
	e := breakerHosts.entradas[host]
	if e == nil {
		e = &entradaBreaker{}
		breakerHosts.entradas[host] = e
	}
	now := time.Now()
	if err != nil {
		// Network-level failure: only counts toward the (higher) hang
		// threshold so a flaky egress IP never parks a healthy host on two
		// quick blips.
		if now.Sub(e.horaColgados) > breakerHostsWindow {
			e.colgados = 0
		}
		e.colgados++
		e.horaColgados = now
		if e.colgados >= breakerHostsMaxHang {
			e.estacionadoHasta = now.Add(breakerHostsParkTime)
			e.colgados = 0
			e.cincoXX = 0
		}
		return
	}
	if esGateway5xx(statusCode) {
		if now.Sub(e.horaCincoXX) > breakerHostsWindow {
			e.cincoXX = 0
		}
		e.cincoXX++
		e.horaCincoXX = now
		if e.cincoXX >= breakerHostsMax5xx {
			e.estacionadoHasta = now.Add(breakerHostsParkTime)
			e.cincoXX = 0
			e.colgados = 0
		}
		return
	}
	// Definitive server reply (2xx/3xx/4xx, including 429): the origin is
	// reachable, so whatever 5xxes happened before were transient.
	e.cincoXX = 0
	e.colgados = 0
}

// NewBreakerTransport wraps [inner] with the shared host breaker. While a host
// is parked its requests return a synthetic HTTP 522 without network I/O, so
// callers see a fast, definitive failure instead of waiting out a timeout.
