// ─────────────────────────────────────────────────────────────
// arcod_acceso.go — Configuración del canal arcod: dirección,
// token y encendido. Llega de Ajustes (setExtensionSettings con
// extension_id "flac-rescue") y se aplica en caliente.
//
// Reglas del campo "arcod":
//
//	(vacío)       → se queda como está (encendido de fábrica)
//	off | 0 | no  → se apaga (el rescate sigue con espejos y sitios)
//	http://…      → instancia PROPIA: el canal se apunta ahí
//
// El campo "arcod_token" es el Bearer opcional de esa instancia (su
// JWT de Supabase). Sirve para el día que la instancia exija sesión
// para el stream: el canal sigue funcionando sin tocar la app.
//
// Es best-effort a propósito: un ajuste mal pegado se ignora y se
// conserva el actual, para que no rompa el rescate.
//
// Se conecta con: client.go (SetSettings), arcod_json.go (Bearer) y
// arcod.go (resolución).
// Parte del flujo: rescate de FLAC por stream y por descarga.
// ─────────────────────────────────────────────────────────────

package flacrescue

import "strings"

// claveTokenArcod es el ajuste que trae el Bearer de una instancia propia.
const claveTokenArcod = "arcod_token"

// baseArcodActiva devuelve la dirección configurada sin barra final, para no
// armar "host//api/...". Cualquier valor que no sea una URL (o vacío) cae en la
// instancia pública.
func (c *Client) baseArcodActiva() string {
	c.arcodConfMu.RLock()
	base := c.arcodBase
	c.arcodConfMu.RUnlock()
	if !esURLArcod(base) {
		return baseArcod
	}
	return strings.TrimRight(base, "/")
}

// tokenArcod devuelve el Bearer configurado (vacío = instancia abierta).
func (c *Client) tokenArcod() string {
	c.arcodConfMu.RLock()
	defer c.arcodConfMu.RUnlock()
	return c.arcodToken
}

// arcodEncendido reporta si el canal está habilitado por ajuste.
func (c *Client) arcodEncendido() bool {
	c.arcodConfMu.RLock()
	defer c.arcodConfMu.RUnlock()
	return c.arcodActivo
}

// aplicarAjusteArcod lee el encendido/dirección de "arcod" y el Bearer de
// "arcod_token". Un campo vacío NO cambia lo que ya había: en Ajustes, "vacío"
// y "sin tocar" llegan igual y no se puede distinguir.
func (c *Client) aplicarAjusteArcod(settings map[string]string) {
	valor := strings.TrimSpace(settings["arcod"])
	token := strings.TrimSpace(settings[claveTokenArcod])

	c.arcodConfMu.Lock()
	defer c.arcodConfMu.Unlock()
	if token != "" {
		c.arcodToken = token
	}
	if valor == "" {
		return
	}
	if esURLArcod(valor) {
		// Instancia propia: el canal se apunta ahí y queda encendido. Si la
		// dirección cambió, la puerta memorizada era de la instancia anterior
		// y no dice nada de esta (ver arcod_stream.go).
		nueva := strings.TrimRight(valor, "/")
		cambiada := nueva != c.arcodBase
		c.arcodBase = nueva
		c.arcodActivo = true
		if cambiada {
			c.olvidarPuertaArcod()
		}
		return
	}
	c.arcodActivo = !esApagado(valor)
}

// esURLArcod dice si el ajuste es una dirección de instancia propia. Se exige
// el esquema completo para no confundir una palabra suelta ("arcod", "sí") con
// una URL.
func esURLArcod(valor string) bool {
	minuscula := strings.ToLower(strings.TrimSpace(valor))
	return strings.HasPrefix(minuscula, "http://") || strings.HasPrefix(minuscula, "https://")
}
