package httpclient

import (
	"context"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// transporteDoHFalso cuenta las consultas que llegan y responde un A record
// público (el guard SSRF descarta los privados, así que no sirve 127.0.0.1).
type transporteDoHFalso struct {
	peticiones int32
	demora     time.Duration
}

func (t *transporteDoHFalso) RoundTrip(*http.Request) (*http.Response, error) {
	atomic.AddInt32(&t.peticiones, 1)
	if t.demora > 0 {
		time.Sleep(t.demora)
	}
	cuerpo := `{"Status":0,"Answer":[{"name":"ejemplo.com","type":1,"data":"93.184.216.34"}]}`
	return &http.Response{
		StatusCode: http.StatusOK,
		Body:       io.NopCloser(strings.NewReader(cuerpo)),
		Header:     make(http.Header),
	}, nil
}

func gestorDoHFalso(tr *transporteDoHFalso) *DNSManager {
	return &DNSManager{
		resolvedores: []*resolvedorDoH{{
			nombre:  "falso",
			urlBase: "https://doh.falso/dns-query",
			cliente: &http.Client{Transport: tr},
		}},
		almacenCache: map[string]*entradaCacheDNS{},
	}
}

// TestResolve_ComparteConsultaEnVuelo fija el single-flight: sin él, cada dial
// lanzaba su propia consulta DoH al mismo host, así que una búsqueda con N
// peticiones paralelas generaba N consultas idénticas (latencia, conexiones y
// RAM de más). Debe hacerse UNA.
func TestResolve_ComparteConsultaEnVuelo(t *testing.T) {
	tr := &transporteDoHFalso{demora: 60 * time.Millisecond}
	dm := gestorDoHFalso(tr)

	const llamadas = 8
	var wg sync.WaitGroup
	errs := make([]error, llamadas)
	ips := make([][]net.IP, llamadas)
	listos := make(chan struct{})

	for i := 0; i < llamadas; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			<-listos // arrancar todas a la vez: la ventana de la consulta las solapa
			ips[i], errs[i] = dm.Resolve(context.Background(), "ejemplo.com")
		}(i)
	}
	close(listos)

	// Espera un momento para que todas entren antes de que la primera termine y
	// libere la caché (la demora del transporte es la que ensancha la ventana).
	time.Sleep(20 * time.Millisecond)
	<-time.After(0)
	wg.Wait()

	if n := atomic.LoadInt32(&tr.peticiones); n != 1 {
		t.Fatalf("esperaba 1 consulta DoH compartida, hubo %d", n)
	}
	for i := 0; i < llamadas; i++ {
		if errs[i] != nil {
			t.Fatalf("llamada %d devolvió error: %v", i, errs[i])
		}
		if len(ips[i]) != 1 || ips[i][0].String() != "93.184.216.34" {
			t.Fatalf("llamada %d devolvió IPs inesperadas: %v", i, ips[i])
		}
	}
}

// TestResolve_CacheSirveRepeticiones: la segunda resolución del mismo host no
// debe volver a consultar.
func TestResolve_CacheSirveRepeticiones(t *testing.T) {
	tr := &transporteDoHFalso{}
	dm := gestorDoHFalso(tr)

	for i := 0; i < 3; i++ {
		if _, err := dm.Resolve(context.Background(), "ejemplo.com"); err != nil {
			t.Fatalf("resolución %d falló: %v", i, err)
		}
	}
	if n := atomic.LoadInt32(&tr.peticiones); n != 1 {
		t.Fatalf("esperaba 1 consulta con caché caliente, hubo %d", n)
	}
}
