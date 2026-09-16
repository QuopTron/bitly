// ─────────────────────────────────────────────────────────────
// qobuz_ajustes.go — Ajustes del canal "Qobuz firmado".
//
// Llegan por el mismo camino que los espejos (setExtensionSettings con
// extension_id "flac-rescue"), así que el usuario los pega en Ajustes →
// Credenciales sin actualizar la app:
//
//	qobuz_app_id      → app_id de la API de Qobuz
//	qobuz_app_secret  → app_secret con el que se firma
//	qobuz_keys_url    → URL que publica {appId, appSecret}: alternativa a
//	                    pegarlos a mano (la app los refresca sola si rotan)
//	qobuz_user_token  → token de usuario (opcional; va por CABECERA)
//	qobuz_api_base    → API a usar (por defecto la de Qobuz; sirve para
//	                    apuntar a un proxy propio)
//	qobuz_format_id   → id de formato del stream (por defecto 5 = FLAC)
//
// El canal queda apagado (ni una petición) si no hay ni claves a mano ni
// origen de claves.
//
// Es best-effort igual que el resto de los ajustes: un valor inválido se
// ignora y se conserva el actual, para que un pegado a medias no apague
// el canal ni rompa el rescate por espejos.
//
// Se conecta con: client.go (SetSettings) y qobuz_firmado.go (uso).
// Parte del flujo: rescate de audio por ISRC.
// ─────────────────────────────────────────────────────────────

package flacrescue

import "strings"

// clavesAjustesQobuz son los ajustes que administra este canal.
var clavesAjustesQobuz = []string{
	"qobuz_app_id", "qobuz_app_secret", "qobuz_user_token",
	"qobuz_api_base", "qobuz_format_id", "qobuz_keys_url",
}

// tocaQobuz reporta si [settings] trae algún ajuste del canal. Sirve para
// no reescribir la configuración (ni tirar la caché) cuando el Map que
// llega es de otra cosa.
func tocaQobuz(settings map[string]string) bool {
	for _, k := range clavesAjustesQobuz {
		if _, ok := settings[k]; ok {
			return true
		}
	}
	return false
}

// aplicarAjustesQobuz actualiza las credenciales del canal. Devuelve true
// cuando algo cambió de verdad (para invalidar la caché de resoluciones).
func (c *Client) aplicarAjustesQobuz(settings map[string]string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	cambio := false
	asignar := func(destino *string, clave, prefijo string) {
		v := strings.TrimSpace(settings[clave])
		if v == "" || (prefijo != "" && !strings.HasPrefix(v, prefijo)) {
			return
		}
		if *destino != v {
			*destino = v
			cambio = true
		}
	}

	asignar(&c.qobuzAppID, "qobuz_app_id", "")
	asignar(&c.qobuzSecreto, "qobuz_app_secret", "")
	asignar(&c.qobuzToken, "qobuz_user_token", "")
	asignar(&c.qobuzBase, "qobuz_api_base", "http")
	asignar(&c.qobuzKeysURL, "qobuz_keys_url", "http")
	if v := strings.TrimSpace(settings["qobuz_format_id"]); v != "" {
		if v != c.qobuzFormato {
			c.qobuzFormato = v
			cambio = true
		}
	}
	return cambio
}
