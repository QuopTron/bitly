package httpclient

import (
	"net"
	"net/http"
	"sync"
	"time"
)

// DNSManager gestiona resolución DoH con varios resolvedores, cache y protección SSRF.
type DNSManager struct {
	resolvedores     []*resolvedorDoH
	almacenCache     map[string]*entradaCacheDNS
	mutexCache       sync.RWMutex
	permitirPrivadas bool
	mutex            sync.Mutex

	// enVuelo agrupa las consultas DoH en curso por hostname (single-flight).
	// Se guarda con mutexCache para que "mirar la caché" y "apuntarse a la
	// consulta en curso" sean una sola operación atómica.
	enVuelo map[string]*vueloDNS
}

// vueloDNS es una consulta DoH compartida: el primero que la pide la ejecuta y
// los demás esperan en `hecho` en vez de lanzar su propia consulta.
type vueloDNS struct {
	hecho chan struct{}
	ips   []net.IP
	err   error
}

type resolvedorDoH struct {
	cliente *http.Client
	urlBase string
	nombre  string
}

type entradaCacheDNS struct {
	ips      []net.IP
	expira   time.Time
	negativo bool
}

var (
	dnsGlobal     *DNSManager
	onceDNSGlobal sync.Once
)

// GetDNSManager devuelve el gestor DNS singleton.
