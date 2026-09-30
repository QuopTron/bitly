// ─────────────────────────────────────────────────────────────
// conteo.go — Cuántas peticiones HTTP salen del proceso, por host.
//
// Por qué existe: para optimizar el stream y la descarga hace falta
// contestar "¿cuántas idas a la red cuesta un tap?" con un número y no con
// una impresión. El backend no tiene un único punto por donde pase todo el
// tráfico (hay decenas de http.Client), así que el conteo se instala en el
// envoltorio de los transportes compartidos: los que usan el transporte por
// defecto, los de media (streaming/descarga), los de las extensiones y los
// del canal de rescate FLAC.
//
// Es SOLO observación: el wrapper devuelve la respuesta y el error tal cual,
// sin tocar headers, cuerpo ni errores. Lo único que hace de más es un lock
// corto por petición, despreciable al lado de la ida a la red.
//
// Se conecta con: el RPC/REST de diagnóstico y con los tests de línea base.
// Parte del flujo: medición de latencia de stream y descarga.
// ─────────────────────────────────────────────────────────────

package httpclient

import (
	"errors"
	"net/http"
	"strings"
	"sync"
	"time"
)

// maxHostesConteo acota el mapa por host: los CDNs rotan subdominios y una
// sesión larga podría acumular entradas que nadie mira. Lo que se pasa del
// techo cae a "otros", que sigue sumando en el total.
const maxHostesConteo = 256

// EstadoRed es el snapshot expuesto por el diagnóstico.
type EstadoRed struct {
	Total     int64            `json:"total"`
	PorHost   map[string]int64 `json:"porHost"`
	PorMetodo map[string]int64 `json:"porMetodo"`
	Otros     int64            `json:"otros"`
	Desde     time.Time        `json:"desde"`
	Segundos  float64          `json:"segundos"`
}

type conteoRed struct {
	mu        sync.Mutex
	total     int64
	porHost   map[string]int64
	porMetodo map[string]int64
	otros     int64
	desde     time.Time
}

var conteo = &conteoRed{
	porHost:   map[string]int64{},
	porMetodo: map[string]int64{},
	desde:     time.Now(),
}

// registrar anota UNA petición. Se llama ANTES de delegar: una petición que
// muere en el dial igual costó una ida a la red, y es justo lo que interesa
// contar cuando se mide un tap.
func (c *conteoRed) registrar(req *http.Request) {
	if req == nil || req.URL == nil {
		return
	}
	host := strings.ToLower(req.URL.Hostname())
	metodo := req.Method
	if metodo == "" {
		metodo = "GET"
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	c.total++
	if _, ok := c.porHost[host]; ok {
		c.porHost[host]++
	} else if len(c.porHost) < maxHostesConteo {
		c.porHost[host] = 1
	} else {
		c.otros++
	}
	c.porMetodo[metodo]++
}

// EstadoConteo devuelve una copia del acumulado. Es seguro llamarlo con
// peticiones en vuelo.
func EstadoConteo() EstadoRed {
	conteo.mu.Lock()
	defer conteo.mu.Unlock()

	hostes := make(map[string]int64, len(conteo.porHost))
	for k, v := range conteo.porHost {
		hostes[k] = v
	}
	metodos := make(map[string]int64, len(conteo.porMetodo))
	for k, v := range conteo.porMetodo {
		metodos[k] = v
	}
	desde := conteo.desde
	segundos := time.Since(desde).Seconds()
	if segundos < 0 {
		segundos = 0
	}
	return EstadoRed{
		Total:     conteo.total,
		PorHost:   hostes,
		PorMetodo: metodos,
		Otros:     conteo.otros,
		Desde:     desde,
		Segundos:  segundos,
	}
}

// ReiniciarConteo deja el acumulado en cero y reinicia el reloj. El patrón de
// uso del diagnóstico es: reiniciar → hacer UN tap → leer, así el total que
// se ve es exactamente lo que costó ese tap.
func ReiniciarConteo() {
	conteo.mu.Lock()
	defer conteo.mu.Unlock()
	conteo.total = 0
	conteo.otros = 0
	conteo.porHost = map[string]int64{}
	conteo.porMetodo = map[string]int64{}
	conteo.desde = time.Now()
}

// transporteConteo envuelve cualquier RoundTripper sumando peticiones.
type transporteConteo struct {
	base http.RoundTripper
}

func (t *transporteConteo) RoundTrip(req *http.Request) (*http.Response, error) {
	conteo.registrar(req)
	return t.base.RoundTrip(req)
}

// CloseIdleConnections se propaga al transporte de adentro: envolver no puede
// costarle al proceso la capacidad de cerrar conexiones ociosas (la usan los
// tests de httpclient y el cierre del canal de rescate).
func (t *transporteConteo) CloseIdleConnections() {
	if c, ok := t.base.(interface{ CloseIdleConnections() }); ok {
		c.CloseIdleConnections()
	}
}

// ContarTransporte devuelve [base] envuelto en el conteo. Es idempotente: si
// ya está envuelto, lo devuelve igual. Un nil se resuelve al transporte por
// defecto EN EL MOMENTO de la llamada (no en cada RoundTrip), así un wrapper
// jamás puede apuntarse a sí mismo.
func ContarTransporte(base http.RoundTripper) http.RoundTripper {
	// Primero se resuelve nil, DESPUÉS la idempotencia: http.DefaultTransport
	// puede estar ya envuelto, y en ese caso se devuelve tal cual (envolverlo
	// otra vez contaría cada petición dos veces).
	if base == nil {
		base = http.DefaultTransport
	}
	if base == nil {
		// Red de seguridad: net/http siempre instala el suyo, pero este
		// envoltorio tampoco debe romper si alguien lo vacía a mano.
		return &transporteConteo{base: transporteNulo{}}
	}
	if c, ok := base.(*transporteConteo); ok {
		return c
	}
	return &transporteConteo{base: base}
}

// transporteNulo existe solo como red de seguridad de ContarTransporte(nil)
// cuando ni siquiera http.DefaultTransport está instalado (no ocurre en
// producción, pero sí en tests que corren antes del init).
type transporteNulo struct{}

var errSinTransporte = errors.New("httpclient: sin transporte HTTP instalado")

func (transporteNulo) RoundTrip(*http.Request) (*http.Response, error) {
	return nil, errSinTransporte
}

// BaseDeConteo devuelve el *http.Transport real que hay DEBAJO del envoltorio
// de conteo, o el propio transporte si nadie lo envolvió. Devuelve nil si por
// el medio hay algo que no es un *http.Transport.
//
// Existe porque los tests de ajuste necesitan leer MaxIdleConnsPerHost y
// compañía sin que el envoltorio se interponga en la aserción de tipos.
func BaseDeConteo(t http.RoundTripper) *http.Transport {
	// Bucle por si acaso hubiera envoltorios anidados: con ContarTransporte
	// idempotente no deberían existir, pero desenvolver de más no cuesta nada.
	for {
		c, ok := t.(*transporteConteo)
		if !ok {
			break
		}
		t = c.base
	}
	tr, _ := t.(*http.Transport)
	return tr
}

// baseDefecto es BaseDeConteo aplicado al transporte por defecto.
func baseDefecto() *http.Transport {
	return BaseDeConteo(http.DefaultTransport)
}

// instalarConteoDefecto envuelve el transporte por defecto UNA sola vez.
//
// Por qué no se hace en init(): el envoltorio cambia el TIPO de
// http.DefaultTransport, y el ajuste de arriba (que corre en el init del
// paquete) necesita seguir viendo el *http.Transport de adentro. El orden es:
// ajustar → envolver. Una segunda llamada (los tests re-inicializan el
// backend) detecta que ya está envuelto y no hace nada.
func instalarConteoDefecto() {
	if _, ok := http.DefaultTransport.(*transporteConteo); ok {
		return
	}
	http.DefaultTransport = &transporteConteo{base: http.DefaultTransport}
}
