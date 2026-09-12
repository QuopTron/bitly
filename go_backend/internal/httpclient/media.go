// ─────────────────────────────────────────────────────────────
// media.go — Transporte y cliente HTTP para MEDIA (audio).
//
// Por qué es distinto del cliente normal: el problema del streaming y
// la descarga no es "cuánto tarda", es "cuántas conexiones puedo
// reutilizar al mismo CDN". El transporte por defecto de Go solo deja
// 2 conexiones ociosas por host, así que un flujo troceado (pedir
// rango, esperar, pedir el siguiente) reabre TLS una y otra vez.
//
// Además:
//   - NO se pone timeout global: un tema puede durar minutos.
//   - Los buffers de lectura/escritura son grandes: menos syscalls.
//   - HTTP/2 habilitado: multiplexa los rangos en una sola conexión.
//
// Se conecta con: streaming/server_core.go y download/orchestrator.
// Parte del flujo: entrega del audio al reproductor y descarga a disco.
// ─────────────────────────────────────────────────────────────

package httpclient

import (
	"net"
	"net/http"
	"time"
)

// NewMediaTransport crea el transporte para media. Es agresivo reutilizando
// conexiones por host a propósito: el streaming troceado hace muchas
// peticiones seguidas al MISMO host, y cada conexión nueva cuesta un
// handshake TLS que se nota como un hueco en la reproducción.
func NewMediaTransport() *http.Transport {
	return &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		DialContext: (&net.Dialer{
			Timeout:   15 * time.Second,
			KeepAlive: 30 * time.Second,
		}).DialContext,
		// Muchas conexiones al mismo CDN listas para reusar.
		MaxIdleConns:        128,
		MaxIdleConnsPerHost: 32,
		IdleConnTimeout:     90 * time.Second,
		TLSHandshakeTimeout: 15 * time.Second,
		// Una cabecera lenta no puede colgar el stream indefinidamente,
		// pero el CUERPO sí puede tardar (no hay timeout global).
		ResponseHeaderTimeout: 25 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		ForceAttemptHTTP2:     true,
		ReadBufferSize:        256 * 1024,
		WriteBufferSize:       256 * 1024,
	}
}

// NewMediaClient envuelve el transporte de media en un cliente SIN timeout
// global: cortar la descarga de un tema de 10 minutos a los 30 segundos es
// exactamente el bug que este cliente evita. Las cabeceras sí tienen límite
// (ResponseHeaderTimeout) y el llamador puede acotar cada petición con un
// context si lo necesita.
func NewMediaClient() *http.Client {
	return &http.Client{
		Transport: NewMediaTransport(),
		// Sin Timeout: la duración la decide el tamaño del tema.
		Timeout: 0,
		Jar:     nil,
	}
}
