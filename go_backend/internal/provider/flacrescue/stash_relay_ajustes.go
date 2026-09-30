// ─────────────────────────────────────────────────────────────
// stash_relay_ajustes.go — Ajuste del canal "stash-relay".
//
// Llega por el mismo camino que los espejos (setExtensionSettings con
// extension_id "flac-rescue"). El campo "stash_relay" acepta:
//
//	(vacío)      → se queda como está (encendido de fábrica)
//	off|0|no     → se apaga (el rescate sigue con arcod, espejos y sitios)
//	http://…     → otra config: la URL del JSON firmado que publica el
//	               relay a usar (para una instancia PROPIA, o para
//	               saltar la config de fábrica del proyecto Stash)
//
// El relay_key NO se configura a mano: viene dentro del JSON de la config,
// así que rotarlo no exige tocar la app. Es best-effort, como el resto de
// los ajustes: un valor inválido se ignora y se conserva el actual.
//
// Se conecta con: client.go (SetSettings) y stash_relay.go (uso).
// Parte del flujo: rescate de audio por ISRC.
// ─────────────────────────────────────────────────────────────

package flacrescue

import "strings"

// claveStashRelay es el ajuste que enciende/apaga o repunta el canal.
const claveStashRelay = "stash_relay"

// aplicarAjusteStash lee "stash_relay". Un campo vacío NO cambia lo que ya
// había: en Ajustes, "vacío" y "sin tocar" llegan igual y no se distinguen.
func (c *Client) aplicarAjusteStash(settings map[string]string) {
	valor := strings.TrimSpace(settings[claveStashRelay])
	if valor == "" {
		return
	}
	// La config se precalienta FUERA del candado: precalentarStashRelay pide el
	// candado para leer y tomarlo adentro del bloqueo lo trabaría.
	precalentar, cambio := c.fijarAjusteStash(valor)
	if !cambio {
		// Ajustes se vuelve a mandar entero en cada arranque, así que el valor
		// suele llegar igual: no se toca nada para no levantar una pausa vigente.
		return
	}
	// Un ajuste NUEVO levanta la pausa: puede ser un relay que ya no es el que
	// contestó 503, o el mismo que el usuario acaba de volver a encender.
	c.reiniciarPausaRelay()
	if precalentar {
		c.precalentarStashRelay()
	}
}

// fijarAjusteStash aplica el valor y devuelve (precalentar, cambio): si conviene
// pedir la config (canal encendido y sin una utilizable en la mano) y si el
// ajuste es DISTINTO del que ya estaba. [cambio] existe para que un reenvío
// idéntico de Ajustes no levante la pausa de un relay ocupado.
func (c *Client) fijarAjusteStash(valor string) (precalentar, cambio bool) {
	c.stashConfMu.Lock()
	defer c.stashConfMu.Unlock()
	if strings.HasPrefix(strings.ToLower(valor), "http") {
		nueva := strings.TrimRight(valor, "/")
		if nueva != c.stashConfigURL {
			// Otra config: lo cacheado era de la anterior y no dice nada de
			// esta, así que se descarta (base y clave nuevas).
			c.stashConfigURL = nueva
			c.stashRelayCfg = relayStash{}
			cambio = true
		}
		c.stashActivo = true
		return c.stashRelayCfg.base == "", cambio
	}
	encendido := !esApagado(valor)
	if encendido != c.stashActivo {
		cambio = true
	}
	c.stashActivo = encendido
	return c.stashActivo && c.stashRelayCfg.base == "", cambio
}
