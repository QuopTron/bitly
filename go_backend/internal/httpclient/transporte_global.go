package httpclient

import (
	"net/http"
	"time"
)

// OptimizarTransportePorDefecto sube los límites del transporte global de
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
//
// Se llama UNA vez al inicializar el backend, antes de que haya peticiones en
// vuelo; mutar un transporte en uso no sería seguro.
func OptimizarTransportePorDefecto() {
	tr, ok := http.DefaultTransport.(*http.Transport)
	if !ok || tr == nil {
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
