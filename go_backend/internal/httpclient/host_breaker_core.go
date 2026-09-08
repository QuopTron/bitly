package httpclient

import (
	"net/url"
	"strings"
	"sync"
	"time"
)

const (
	// breakerHostsMax5xx es cuántos 5xx de gateway dentro de la ventana estacionan el host.
	breakerHostsMax5xx = 2
	// breakerHostsMaxHang es cuántas fallas de red consecutivas (timeouts/TLS/dial)
	// dentro de la ventana estacionan el host; mayor que el umbral 5xx porque los
	// blips transitorios de salida son comunes y no deben bloquear un host sano.
	breakerHostsMaxHang = 3
	// breakerHostsWindow es cuánto deben durar las fallas consecutivas para contar como el mismo apagón.
	breakerHostsWindow = 30 * time.Second
	// breakerHostsParkTime es cuánto tiempo se salta un host estacionado antes de
	// permitirle una petición real de nuevo (origen recuperado se reutiliza rápido).
	breakerHostsParkTime = 90 * time.Second
)

// entradaBreaker registra el historial reciente de fallas de un solo host.
type entradaBreaker struct {
	cincoXX          int       // respuestas 5xx de gateway en la ventana
	horaCincoXX      time.Time // hora del último 5xx
	colgados         int       // fallas de red en la ventana
	horaColgados     time.Time // hora de la última falla de red
	estacionadoHasta time.Time // mientras ahora < estacionadoHasta, las peticiones se cortan
}

var breakerHosts = &estadoBreaker{entradas: map[string]*entradaBreaker{}}

type estadoBreaker struct {
	mutex    sync.Mutex
	entradas map[string]*entradaBreaker
}

// hostDe extrae el hostname en minúsculas de una URL cruda.
func hostDe(rawURL string) string {
	if rawURL == "" {
		return ""
	}
	if u, err := url.Parse(rawURL); err == nil && u.Hostname() != "" {
		return strings.ToLower(u.Hostname())
	}
	return ""
}

// BreakerBlocked reporta si el host de [rawURL] está estacionado y su petición
// debe fallar rápido sin tocar la red.
func BreakerBlocked(rawURL string) bool {
	host := hostDe(rawURL)
	if host == "" {
		return false
	}
	breakerHosts.mutex.Lock()
	defer breakerHosts.mutex.Unlock()
	e := breakerHosts.entradas[host]
	return e != nil && time.Now().Before(e.estacionadoHasta)
}

// esGateway5xx reports whether [code] is a gateway/origin error — Cloudflare
// 52x plus the common 500/502/503/504. These mean the origin (not the edge) is
// down, and retrying immediately will just wait for the same failure again.
