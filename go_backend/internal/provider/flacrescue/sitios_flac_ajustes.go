// ─────────────────────────────────────────────────────────────
// sitios_flac_ajustes.go — Ajuste "sitios" del canal de sitios
// raspables de FLAC: encenderlos, apagarlos o limitarlos a una lista,
// con el mismo formato que el ajuste de espejos.
//
// Por qué best-effort: un ajuste mal pegado no puede romper el rescate
// ni la reproducción; un valor que no se entiende se ignora y quedan los
// sitios de fábrica.
//
// Se conecta con: sitios_flac.go (registro) y client.go (SetSettings).
// Parte del flujo: configuración del rescate de FLAC.
// ─────────────────────────────────────────────────────────────

package flacrescue

import "strings"

// habilitarSitios aplica el ajuste "sitios" que llega de Ajustes →
// Credenciales, con el mismo formato que los espejos:
//
//	(vacío)                       → quedan los sitios de fábrica
//	off | 0 | no                  → se apagan (solo espejos/Qobuz firmado)
//	https://sitio.com,https://x/  → se usan SOLO los sitios de esa lista
//	                                (una URL desconocida se ignora en silencio)
//
// Es best-effort a propósito: un ajuste mal pegado no puede romper el
// rescate ni la reproducción.
func (c *Client) habilitarSitios(settings map[string]string) {
	v := strings.TrimSpace(settings["sitios"])
	if v == "" {
		return
	}
	sitios := sitiosConocidos
	if esApagado(v) {
		sitios = nil
	} else if lista := parseMirrors(v); len(lista) > 0 {
		sitios = filtrarSitios(lista)
	}
	c.sitiosMu.Lock()
	c.sitios = sitios
	c.sitiosMu.Unlock()
}

// esApagado reconoce los valores de "apagado" del ajuste.
func esApagado(v string) bool {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "off", "0", "no", "false", "apagado":
		return true
	}
	return false
}

// filtrarSitios se queda solo con los sitios conocidos que el usuario
// habilitó, comparando por host.
func filtrarSitios(bases []string) []sitioFLAC {
	var salida []sitioFLAC
	for _, conocido := range sitiosConocidos {
		host := hostDe(conocido.base())
		for _, base := range bases {
			if hostDe(base) == host {
				salida = append(salida, conocido)
				break
			}
		}
	}
	return salida
}

// hostDe extrae el host de una URL (o devuelve el texto tal cual).
func hostDe(base string) string {
	if i := strings.Index(base, "://"); i >= 0 {
		base = base[i+3:]
	}
	base = strings.TrimRight(base, "/")
	if i := strings.IndexAny(base, "/?#"); i >= 0 {
		base = base[:i]
	}
	return strings.ToLower(base)
}
