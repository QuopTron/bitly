// ─────────────────────────────────────────────────────────────
// proxy.go — Proxy opcional para TODO el egreso de flac-rescue.
//
// Por qué acá y no en cada cliente: los espejos (monochrome/dzr),
// los sitios raspables (superflac y sus instancias), el canal arcod y
// el origen de claves del canal Qobuz firmado salen por dos clientes
// nada más: `Client.http` y las sesiones de `nuevaSesionSitio()`. Con
// un TRANSPORTE compartido, cuyo campo Proxy consulta el valor vivo en
// cada petición, un ajuste pegado en Ajustes cubre los cuatro caminos
// sin tocar cada archivo por separado — y sin carrera, porque el
// transporte nunca se reemplaza (solo cambia lo que devuelve su `Proxy`).
//
// Para qué sirve: varios de estos sitios y espejos bloquean o
// restringen por región (es el modelo de los proxies por servicio que
// usa Murglar). Sin esto, un sitio bloqueado no tenía salida: no hay
// reintento posible cuando el problema es geográfico.
//
// Es best-effort a propósito: una URL de proxy que no se entiende se
// ignora y se conserva la anterior, así pegar mal el ajuste no puede
// romper el rescate ni la reproducción. Vacío = sin proxy (directo).
//
// Se conecta con: client.go (SetSettings), sitios_flac_http.go
// (nuevaSesionSitio), resolucion.go, qobuz_*.go y arcod_json.go.
// Parte del flujo: configuración del rescate de audio.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

// proxyMu protege proxyVivo: Ajustes lo cambia en caliente mientras
// otra goroutine resuelve un rescate, así que la lectura tiene que ser
// segura.
var (
	proxyMu   sync.RWMutex
	proxyVivo *url.URL
)

// transporteRescate es el transporte COMPARTIDO por todos los clientes
// de este paquete (espejos, sitios, arcod y Qobuz firmado).
//
// La clave es que `Proxy` es una FUNCIÓN que lee el proxy vivo: el
// transporte se arma una sola vez y cambiar el ajuste surte efecto en
// la siguiente petición. Reemplazar el `Transport` de un `http.Client`
// en caliente sería una carrera con las peticiones en vuelo.
//
// Los valores son los del transporte por defecto de Go con más
// conexiones ociosas por host: un rescate dispara varias peticiones
// seguidas al MISMO sitio (abrir sesión → buscar → descargar →
// consultar el trabajo), y con 2 por host se reabría TLS en medio.
var transporteRescate = &http.Transport{
	Proxy: func(*http.Request) (*url.URL, error) { return proxyActual(), nil },
	// Respuesta que nunca llega: sin techo, la conexión quedaba colgada
	// (mismo motivo que en internal/httpclient).
	TLSHandshakeTimeout:   10 * time.Second,
	ResponseHeaderTimeout: 25 * time.Second,
	MaxIdleConns:          64,
	MaxIdleConnsPerHost:   8,
	IdleConnTimeout:       90 * time.Second,
	ForceAttemptHTTP2:     true,
}

// SetProxy aplica el ajuste "proxy" que llega de Ajustes:
//
//	(vacío)                 → sin proxy (todas las salidas directas)
//	http://host:puerto      → proxy HTTP
//	https://host:puerto     → proxy HTTPS
//	socks5://host:puerto    → proxy SOCKS5
//	socks5h://user:pass@h:p → SOCKS5 con DNS del proxy y autenticación
//
// Un valor que no sea una URL con esquema y host se IGNORA (se conserva
// el proxy anterior): un ajuste mal pegado no puede dejar el rescate sin
// salida. La contraseña, si viene, viaja en la URL y la maneja la
// librería estándar.
func SetProxy(raw string) {
	v := strings.TrimSpace(raw)
	// Vacío = explícitamente sin proxy (el usuario lo borró).
	if v == "" {
		cambiarProxy(nil)
		return
	}
	u, err := url.Parse(v)
	if err != nil || u.Host == "" {
		return
	}
	switch strings.ToLower(u.Scheme) {
	case "http", "https", "socks5", "socks5h":
	default:
		return
	}
	cambiarProxy(u)
}

// proxyActual devuelve el proxy configurado, o nil para salir directo.
func proxyActual() *url.URL {
	proxyMu.RLock()
	defer proxyMu.RUnlock()
	return proxyVivo
}

// cambiarProxy fija el proxy vivo y tira las conexiones ociosas: las que
// quedaron abiertas van por la ruta VIEJA, así que sin esto la primera
// petición después del ajuste podría seguir saliendo directo.
func cambiarProxy(u *url.URL) {
	proxyMu.Lock()
	proxyVivo = u
	proxyMu.Unlock()
	transporteRescate.CloseIdleConnections()
}

// Proxy devuelve el proxy configurado tal como se lo ve en Ajustes ("" si
// no hay). Es para diagnóstico y tests.
func Proxy() string {
	if u := proxyActual(); u != nil {
		return u.String()
	}
	return ""
}

// aplicarAjusteProxy lee la clave "proxy" del bloque de ajustes. Va aparte
// para que SetSettings no crezca con un tema que no tiene que ver con los
// espejos, y para que un test pueda fijarlo sin tocar nada más.
func (c *Client) aplicarAjusteProxy(settings map[string]string) {
	if v, ok := settings["proxy"]; ok {
		SetProxy(v)
	}
}
