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
	if c.fijarAjusteStash(valor) {
		c.precalentarStashRelay()
	}
}

// fijarAjusteStash aplica el valor y devuelve si conviene precalentar la config:
// canal encendido y sin una config utilizable en la mano.
func (c *Client) fijarAjusteStash(valor string) bool {
	c.stashConfMu.Lock()
	defer c.stashConfMu.Unlock()
	if strings.HasPrefix(strings.ToLower(valor), "http") {
		nueva := strings.TrimRight(valor, "/")
		if nueva != c.stashConfigURL {
			// Otra config: lo cacheado era de la anterior y no dice nada de
			// esta, así que se descarta (base y clave nuevas).
			c.stashConfigURL = nueva
			c.stashRelayCfg = relayStash{}
		}
		c.stashActivo = true
		return c.stashRelayCfg.base == ""
	}
	c.stashActivo = !esApagado(valor)
	return c.stashActivo && c.stashRelayCfg.base == ""
}
