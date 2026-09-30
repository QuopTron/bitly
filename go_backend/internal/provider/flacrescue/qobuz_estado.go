// ─────────────────────────────────────────────────────────────
// qobuz_estado.go — Estado de CUENTA del canal Qobuz firmado.
//
// Por qué existe: el canal puede fallar por dos motivos que no tienen
// nada que ver entre sí. Uno es de red (el sitio no responde, la clave
// rotó) y se paga una vez. El otro es de CUENTA: sin sesión de
// suscriptor, Qobuz solo entrega una muestra de 30 s (o degrada a MP3),
// y eso NO cambia de canción a canción. Sin esta marca el canal se
// pagaba en cada resolución —búsqueda por ISRC incluida, que es
// justamente lo que mide el tap— para un fallo que ya se conocía.
//
// Medido en el dispositivo real (Ajustes con las claves del Worker
// inyectadas, sin sesión premium): qobuz-firmado gastaba 2,7 s por
// carrera devolviendo "devolvió una muestra corta" y estiraba la
// carrera de canales entera, que es la que decide cuándo arranca el
// audio.
//
// Los errores son CENTINELA con el mensaje exacto que ya se loguea: así
// se puede reconocer la condición con errors.Is sin cambiar lo que ve
// el usuario ni los asserts de los tests.
//
// Se conecta con: qobuz_archivo.go (los devuelve) y resolucion.go
// (marca el canal y alimenta el cortocircuito de rescateAgotado).
// Parte del flujo: rescate de audio por ISRC.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"errors"
	"time"
)

// Los dos son el MISMO hecho (la cuenta no puede servir la canción entera),
// pero se distinguen porque el log ya los reporta por separado.
var (
	errQobuzMuestraCorta = errors.New("qobuz-firmado: Qobuz devolvió una muestra corta, no la canción")
	errQobuzSinSesion    = errors.New("qobuz-firmado: Qobuz pidió sesión (sin token de suscriptor solo entrega MP3)")
)

// ttlQobuzSinSesion es cuánto se recuerda que la cuenta no alcanza. Cinco
// minutos, la misma cifra que la marca de un espejo sin cuentas: si el usuario
// carga una sesión desde Ajustes, SetSettingsQobuz la borra al instante.
const ttlQobuzSinSesion = 5 * time.Minute

// marcarQobuzSinSesion anota que la cuenta no puede servir la canción.
func (c *Client) marcarQobuzSinSesion() {
	c.qobuzSinSesionMu.Lock()
	c.qobuzSinSesionHasta = time.Now().Add(ttlQobuzSinSesion)
	c.qobuzSinSesionMu.Unlock()
}

// qobuzSinSesion reporta si la marca sigue vigente.
func (c *Client) qobuzSinSesion() bool {
	c.qobuzSinSesionMu.Lock()
	defer c.qobuzSinSesionMu.Unlock()
	return time.Now().Before(c.qobuzSinSesionHasta)
}

// olvidarQobuzSinSesion borra la marca: con credenciales nuevas hay que volver
// a intentarlo, porque puede ser otra cuenta (con suscriptor).
func (c *Client) olvidarQobuzSinSesion() {
	c.qobuzSinSesionMu.Lock()
	c.qobuzSinSesionHasta = time.Time{}
	c.qobuzSinSesionMu.Unlock()
}
