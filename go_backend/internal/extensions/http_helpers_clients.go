package extensions

import (
	"context"
	"crypto/tls"
	"net"
	"net/http"
	"net/http/cookiejar"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
	"golang.org/x/net/http2"
)

var (
	extHTTPClientOnce sync.Once
	extHTTPClient     *http.Client
)

// YouTube domains that require uTLS fingerprinting to avoid 403 bot-gate.
var youtubeHosts = map[string]bool{
	"www.youtube.com":   true,
	"youtube.com":       true,
	"ytimg.com":         true,
	"googlevideo.com":   true,
	"youtu.be":          true,
	"music.youtube.com": true,
}

func esHostYouTube(url string) bool {
	for host := range youtubeHosts {
		if strings.Contains(url, host) {
			return true
		}
	}
	return false
}

// isGooglevideoHost reports whether [url] points at YouTube's media CDN
// (rr*.googlevideo.com/videoplayback). These carry a signed URL, are served
// over plain HTTP/1.1, and are NOT bot-gated like the InnerTube API — they
// must use the standard DoH client instead of the uTLS/HTTP2 one (whose
// HTTP2 framing breaks on the CDN: "http2: frame too large").
func esHostGooglevideo(url string) bool {
	return strings.Contains(url, "googlevideo.com")
}

// extHTTPClientFor returns the shared, lazily-initialized extension HTTP
// client with a persistent cookie jar.
func clienteHTTPExtPara() *http.Client {
	extHTTPClientOnce.Do(func() {
		jar, _ := cookiejar.New(nil)
		transport := &http.Transport{
			DialContext:       httpclient.NewDoHDialContext(),
			ForceAttemptHTTP2: true,
			MaxIdleConns:      100,
			// 32 por host (antes 10): una búsqueda dispara muchas llamadas
			// simultáneas al MISMO host entre catálogo, detalle y player, y con
			// 10 se reabría TLS a mitad de la búsqueda.
			MaxIdleConnsPerHost:   32,
			IdleConnTimeout:       90 * time.Second,
			TLSHandshakeTimeout:   10 * time.Second,
			ResponseHeaderTimeout: 20 * time.Second,
			ExpectContinueTimeout: time.Second,
			// Compresión ACTIVADA (antes DisableCompression: true). El grueso de
			// lo que pasa por aquí es HTML y JSON de los catálogos, y comprimido
			// pesa 3–10× menos: en red móvil eso es latencia de búsqueda directa.
			//
			// Verificado que no rompe a nadie: Go solo añade Accept-Encoding por
			// su cuenta si el header está ausente, así que las extensiones que
			// necesitan bytes crudos (deezer y soundcloud piden
			// "Accept-Encoding: identity") quedan exactamente igual; y los
			// controles de tamaño por Content-Length de las descargas
			// (file_download.go, repo_download.go) ya tratan el -1 que Go pone
			// al descomprimir, sin falso "truncado". Ningún JS lee
			// content-length, así que tampoco se pierde progreso.
		}
		extHTTPClient = &http.Client{
			Timeout:   30 * time.Second,
			Transport: transport,
			Jar:       jar,
		}
	})
	return extHTTPClient
}

var (
	descargaClienteOnce sync.Once
	descargaCliente     *http.Client
)

// clienteDescargaExtPara es el cliente HTTP para DESCARGAS DE ARCHIVO de las
// extensiones (audio por segmentos, video, subtítulos).
//
// Antes, cada llamada a file.download y a file.downloadSegments armaba su propio
// http.Client CON su propio http.Transport. Eso tenía dos consecuencias reales:
//
//   - Sin reuso de conexiones: cada segmento de una descarga DASH abría TCP +
//     TLS desde cero (100 segmentos = 100 handshakes, y con DoH de por medio).
//     El ancho de banda sobraba y la descarga igual se sentía lenta.
//   - SIN TLSHandshakeTimeout: un servidor que acepta el TCP y se queda callado
//     en el saludo TLS colgaba la descarga para siempre (el
//     ResponseHeaderTimeout no cubre el handshake).
//
// Ahora es único para todo el proceso: las conexiones al CDN sobreviven de un
// segmento al siguiente y de una descarga a la siguiente. Sin Timeout global a
// propósito: un FLAC de 100 MB desde un CDN lento tarda lo que tarda, y quien
// decide es el llamador (el sandbox tiene su propio timeout de operación).
//
// DisableCompression: los bytes que se escriben a disco tienen que ser
// EXACTAMENTE los del archivo, y Content-Length tiene que seguir siendo
// confiable — es lo que usa el guard de descarga truncada de file_download.go
// para no dejar un MP4 cifrado sin su moov atom (irrecuperable). Sin
// compresión transparente no hay ninguna duda.
func clienteDescargaExtPara() *http.Client {
	descargaClienteOnce.Do(func() {
		jar, _ := cookiejar.New(nil)
		descargaCliente = &http.Client{
			Transport: &http.Transport{
				DialContext:           httpclient.NewDoHDialContext(),
				ForceAttemptHTTP2:     true,
				MaxIdleConns:          64,
				MaxIdleConnsPerHost:   16,
				IdleConnTimeout:       90 * time.Second,
				TLSHandshakeTimeout:   15 * time.Second,
				ResponseHeaderTimeout: 30 * time.Second,
				ExpectContinueTimeout: time.Second,
				DisableCompression:    true,
			},
			Jar: jar,
		}
	})
	return descargaCliente
}

// ytHTTPClient is a separate HTTP client for YouTube/InnerTube requests that
// usa uTLS fingerprinting a mimic un real Chrome navegador TLS handshake.// YouTube bot-gates IPs with a Go TLS fingerprint → 403; uTLS solves this.
var (
	ytHTTPClientOnce sync.Once
	ytHTTPClient     *http.Client
)

func ytHTTPClientFor() *http.Client {
	ytHTTPClientOnce.Do(func() {
		jar, _ := cookiejar.New(nil)
		// uTLS dialer mimics Chrome's TLS fingerprint to bypass YouTube bot
		// detection, resolving via DoH so Android's system resolver never
		// fails the dial.
		dialFn := httpclient.NewUTLSDialer(httpclient.FingerprintChrome)
		// YouTube's servers negotiate HTTP/2 over ALPN EVEN when the client
		// only offers http/1.1 (verified: music.youtube.com answers h2), so a
		// plain http/1.1 transport breaks on the h2 frames with "malformed
		// HTTP response". Speak HTTP/2 over the uTLS connection instead.
		tr := &http2.Transport{
			DialTLSContext: func(ctx context.Context, network, addr string, _ *tls.Config) (net.Conn, error) {
				return dialFn(network, addr)
			},
		}
		ytHTTPClient = &http.Client{
			Timeout:   30 * time.Second,
			Transport: tr,
			Jar:       jar,
		}
	})
	return ytHTTPClient
}

// doHTTPCompat returns the old-style {status, body, headers} object.
