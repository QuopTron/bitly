// ─────────────────────────────────────────────────────────────
// cobalt_ajustes.go — PART de cobalt.go: la instancia propia de cobalt que
// llega desde Ajustes (Ajustes → Descargas → Avanzado).
//
// Por qué es un ajuste y no un valor de fábrica: la API pública de
// cobalt.tools pide sesión/API Key, y el principio del proyecto es no depender
// de cuentas ajenas. El usuario puede apuntar a su propia instancia; sin URL
// el respaldo queda APAGADO y no abre ninguna conexión.
//
// Se conecta con: cobalt.go (misma package) y gobackend/extensions_settings.go
// (extensión "youtube") + extensions_actions.go (reinitialize).
// Parte del flujo: descarga (YouTube → segunda vía).
// ─────────────────────────────────────────────────────────────

package youtube

import "strings"

// cobaltConfig es la instancia configurada por el usuario. Vacía = apagado.
type cobaltConfig struct {
	base  string
	token string
}

// activa reporta si hay una instancia configurada.
func (c cobaltConfig) activa() bool { return c.base != "" }

// SetSettings aplica los ajustes que llegan de la app (extensions_settings.go,
// extensión "youtube"). Hoy solo el respaldo de descarga por cobalt.
func (c *Client) SetSettings(settings map[string]string) {
	c.configurarCobalt(settings)
}

// configurarCobalt guarda la instancia propia. Un valor de apagado ("off",
// "0", "no"...) la desactiva, igual que el ajuste de sitios de flac-rescue.
func (c *Client) configurarCobalt(settings map[string]string) {
	base := strings.TrimSpace(settings["cobalt"])
	if cobaltApagado(base) {
		base = ""
	}
	c.mu.Lock()
	c.cobalt = cobaltConfig{
		base:  strings.TrimRight(base, "/"),
		token: strings.TrimSpace(settings["cobalt_token"]),
	}
	c.mu.Unlock()
}

// cobaltApagado reconoce los valores de "apagado" del ajuste.
func cobaltApagado(v string) bool {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "off", "0", "no", "false", "apagado":
		return true
	}
	return false
}

// instanciaCobalt devuelve la instancia configurada ahora mismo.
func (c *Client) instanciaCobalt() cobaltConfig {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.cobalt
}
