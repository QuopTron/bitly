package httpclient

import (
	"sync"
	"time"
)

// optimizarTransportePorDefecto sube los límites del transporte global de
// net/http.
//
// Por qué hace falta: en el backend hay decenas de clientes creados como
// `&http.Client{...}` sin transporte propio, así que todos comparten
// http.DefaultTransport. Ese transporte viene con MaxIdleConnsPerHost = 2, que
// es un valor pensado para un navegador con pocas pestañas, no para este
// patrón de uso: muchas llamadas simultáneas al MISMO host (una búsqueda golpea
// varias veces el mismo catálogo, y el streaming golpea el mismo CDN).
//
// Con 2 conexiones ociosas por host, cada petición extra abre un handshake TLS
// nuevo en medio de la operación, que es exactamente lo que se siente como
// "va lento y a tirones". Los valores de aquí no cambian semántica: solo suben
// cuántas conexiones se reutilizan y ponen techo a las dos esperas que no lo
// tenían (handshake TLS y cabeceras de respuesta).
func optimizarTransportePorDefecto() {
	// baseDefecto mira POR DEBAJO del envoltorio de conteo: si el transporte
	// por defecto ya está envuelto, la aserción directa a *http.Transport
	// fallaría y el ajuste se caería en silencio (quedando con 2 conexiones
	// ociosas por host).
	tr := baseDefecto()
	if tr == nil {
		return
	}
	tr.MaxIdleConns = 128
	tr.MaxIdleConnsPerHost = 16
	tr.IdleConnTimeout = 90 * time.Second
	tr.TLSHandshakeTimeout = 10 * time.Second
	tr.ResponseHeaderTimeout = 25 * time.Second
	tr.ExpectContinueTimeout = time.Second
	tr.ForceAttemptHTTP2 = true
}

// ajusteGlobal garantiza que la configuración se aplique EXACTAMENTE una vez.
var ajusteGlobal sync.Once

// Se aplica en el arranque del paquete, cuando todavía no existe ninguna
// goroutine. Ese "antes" no es un detalle de estilo: mutar los campos de un
// transporte que YA tiene peticiones en vuelo es un data race — net/http lee
// MaxIdleConns, TLSHandshakeTimeout, etc. al mismo tiempo, y el race detector
// lo detecta (pasaba en CI).
func init() {
	ajusteGlobal.Do(optimizarTransportePorDefecto)
	// Después del ajuste (que muta campos y NO debe correr sobre el
	// envoltorio) se instala el conteo de peticiones. Ver conteo.go.
	instalarConteoDefecto()
}

// OptimizarTransportePorDefecto asegura que el transporte global esté ajustado.
//
// Es idempotente y SEGURA de llamar en cualquier momento: el ajuste ya se aplicó
// al arrancar el paquete (ver init), así que una llamada posterior no escribe
// nada. Antes esta función mutaba el transporte en CADA invocación, y el backend
// tiene más de un punto de inicialización (los tests crean el backend varias
// veces mientras una descarga en segundo plano —el manager de binarios— sigue
// corriendo), así que la escritura caía encima de una petición en vuelo.
//
// Se mantiene como API explícita para que el arranque del backend siga
// documentando que el transporte se ajusta una sola vez.
func OptimizarTransportePorDefecto() {
	ajusteGlobal.Do(optimizarTransportePorDefecto)
}
