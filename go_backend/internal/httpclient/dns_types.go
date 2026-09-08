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
