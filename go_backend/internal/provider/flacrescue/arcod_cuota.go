// ─────────────────────────────────────────────────────────────
// arcod_cuota.go — Presupuesto y pausa del canal arcod.
//
// Por qué existe: el sitio atiende a los invitados con un pool de
// tokens de Qobuz SUYO (no del usuario) y publica su propio límite
// por IP en /api/v2/guest/rate-limit. Sin mirarlo, un dispositivo
// seguía pidiendo hasta comerse la espera de un sitio que ya no tiene
// nada que dar, canción tras canción. Con esto:
//   · se consulta ese presupuesto (con caché de 1 min) y, si el sitio
//     dice que estamos limitados o queda poco, el canal se saltea;
//   · un fallo de pool sube el backoff (5 → 10 → 20 → 40 → 60 min) y
//     el primer acierto lo borra.
//
// Es best-effort a propósito: si el endpoint del presupuesto no
// responde, se resuelve igual. El canal nunca se apaga por una
// consulta que no es suya.
//
// Se conecta con: arcod.go (resolverArcod) y client.go (estado).
// Parte del flujo: rescate de FLAC por stream y por descarga.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"encoding/json"
	"errors"
	"time"
)

const (
	// cuotaMinimaArcod son las resoluciones que exigimos libres antes de
	// gastar una: si quedan menos, el canal se corre para que la cuota alcance
	// para lo que el usuario realmente escucha.
	cuotaMinimaArcod = 25
	// ttlCuotaArcod es cuánto se recuerda lo que dijo el sitio. Un minuto: el
	// presupuesto se resetea por hora y no cambia rápido.
	ttlCuotaArcod = time.Minute
	// pausaArcodBase y pausaArcodTope acotan el backoff de los fallos de pool.
	pausaArcodBase = 5 * time.Minute
	pausaArcodTope = 60 * time.Minute
)

// errArcodSinCuota lo devuelve el canal cuando el sitio avisa que no hay
// presupuesto de invitado. Se trata como cualquier otro "esta fuente no
// aporta": el rescate sigue con los espejos y los sitios.
var errArcodSinCuota = errors.New("arcod: sin presupuesto de invitado")

// cuotaArcod es lo último que publicó el sitio sobre nuestro presupuesto.
// sinDato marca una consulta que no se pudo leer: se recuerda para no volver a
// preguntar en cada canción, pero NO bloquea el canal (best-effort).
type cuotaArcod struct {
	leida     time.Time
	restantes int
	limitada  bool
	sinDato   bool
}

// enPausaArcod reporta si el canal quedó en pausa por fallos de pool.
func (c *Client) enPausaArcod() bool {
	c.arcodEstadoMu.Lock()
	defer c.arcodEstadoMu.Unlock()
	return time.Now().Before(c.arcodPausaHasta)
}

// marcarFalloArcod sube el backoff del canal. El primer fallo cuesta 5
// minutos; a partir de ahí se duplica hasta el tope de una hora, así una caída
// larga del sitio (lo normal: su pool de cuentas se vacía) deja de costar
// latencia en cada reproducción.
func (c *Client) marcarFalloArcod() {
	c.arcodEstadoMu.Lock()
	defer c.arcodEstadoMu.Unlock()
	c.arcodFallos++
	pausa := pausaArcodBase
	for i := 1; i < c.arcodFallos && pausa < pausaArcodTope; i++ {
		pausa *= 2
	}
	if pausa > pausaArcodTope {
		pausa = pausaArcodTope
	}
	c.arcodPausaHasta = time.Now().Add(pausa)
}

// marcarAciertoArcod borra el backoff: si el sitio volvió, el canal vuelve a
// intentarlo con la prioridad de siempre.
func (c *Client) marcarAciertoArcod() {
	c.arcodEstadoMu.Lock()
	defer c.arcodEstadoMu.Unlock()
	c.arcodFallos = 0
	c.arcodPausaHasta = time.Time{}
}

// cuotaArcodSuficiente consulta el presupuesto del invitado (con caché) y
// falla solo si el sitio dijo EXPLÍCITAMENTE que no hay lugar. Un endpoint que
// no responde no bloquea el canal.
func (c *Client) cuotaArcodSuficiente() error {
	c.arcodEstadoMu.Lock()
	ultima := c.arcodCuota
	c.arcodEstadoMu.Unlock()

	if ultima.leida.IsZero() || time.Since(ultima.leida) > ttlCuotaArcod {
		leida, ok := c.leerCuotaArcod()
		if !ok {
			leida = cuotaArcod{leida: time.Now(), sinDato: true}
		}
		c.arcodEstadoMu.Lock()
		c.arcodCuota = leida
		c.arcodEstadoMu.Unlock()
		ultima = leida
	}
	if ultima.sinDato {
		return nil
	}
	if ultima.limitada || ultima.restantes < cuotaMinimaArcod {
		return errArcodSinCuota
	}
	return nil
}

// leerCuotaArcod trae el presupuesto que el propio sitio publica. ok=false
// cuando no se pudo leer (endpoint ausente, red, JSON raro): en ese caso el
// llamador resuelve igual.
func (c *Client) leerCuotaArcod() (cuotaArcod, bool) {
	cuerpo, err := c.pedirArcod(c.baseArcodActiva() + "/api/v2/guest/rate-limit")
	if err != nil {
		return cuotaArcod{}, false
	}
	var respuesta struct {
		Remaining int  `json:"remaining"`
		IsLimited bool `json:"isLimited"`
	}
	if err := json.Unmarshal(cuerpo, &respuesta); err != nil {
		return cuotaArcod{}, false
	}
	if respuesta.Remaining == 0 && !respuesta.IsLimited {
		// El sitio no está publicando un número utilizable: se toma como
		// "sin dato" para no apagar el canal por un campo ausente.
		return cuotaArcod{}, false
	}
	return cuotaArcod{
		leida:     time.Now(),
		restantes: respuesta.Remaining,
		limitada:  respuesta.IsLimited,
	}, true
}
