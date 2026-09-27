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

import (
	"net/url"
	"strings"
)

// habilitarSitios aplica el ajuste "sitios" que llega de Ajustes →
// Credenciales, con el mismo formato que los espejos:
//
//	(vacío)                       → quedan los sitios de fábrica
//	off | 0 | no                  → se apagan (solo espejos/Qobuz firmado)
//	https://sitio.com,https://x/  → se usan SOLO los sitios de esa lista
//
// Es best-effort a propósito: un ajuste mal pegado no puede romper el
// rescate ni la reproducción.
//
// NOVEDAD: una URL que no sea de un sitio de fábrica YA NO se ignora. superflac
// es UNA instancia de un mismo software, y el protocolo (sitios_flac_superflac.go)
// es el mismo en todas: pegar la URL de otra instancia la habilita sin tocar el
// código. Si esa instancia no habla el protocolo, su intento falla y el resto de
// la lista sigue (best-effort).
func (c *Client) habilitarSitios(settings map[string]string) {
	v := strings.TrimSpace(settings["sitios"])
	if v == "" {
		return
	}
	sitios := sitiosConocidos
	if esApagado(v) {
		sitios = nil
	} else if lista := parseMirrors(v); len(lista) > 0 {
		sitios = sitiosDeLista(lista)
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

// sitiosDeLista arma la lista de sitios del ajuste RESPETANDO EL ORDEN en que
// el usuario los pegó (antes se reordenaba según los sitios de fábrica).
//
// Un host de fábrica usa su sitio registrado; cualquier otra URL válida se usa
// con el protocolo COMPARTIDO (sitioSuperflac), porque superflac es una
// instancia de muchos. Se deduplica por host y se ignoran los valores que no son
// URLs http(s), así un ajuste mal pegado no rompe nada.
func sitiosDeLista(bases []string) []sitioFLAC {
	var salida []sitioFLAC
	vistos := map[string]bool{}
	for _, base := range bases {
		host := hostDe(base)
		if host == "" || vistos[host] {
			continue
		}
		if conocido := sitioConocidoPorHost(host); conocido != nil {
			vistos[host] = true
			salida = append(salida, conocido)
			continue
		}
		url, ok := baseSitioValida(base)
		if !ok {
			continue
		}
		vistos[host] = true
		salida = append(salida, sitioSuperflac{url: url})
	}
	return salida
}

// sitioConocidoPorHost busca un sitio de fábrica por host, o nil.
func sitioConocidoPorHost(host string) sitioFLAC {
	for _, conocido := range sitiosConocidos {
		if hostDe(conocido.base()) == host {
			return conocido
		}
	}
	return nil
}

// baseSitioValida normaliza una URL de instancia y dice si sirve como base: tiene
// que ser http(s) con host. Se descarta query/fragment y la barra final, porque
// el protocolo arma las rutas con concatenación (/search?..., /downloads?...).
func baseSitioValida(base string) (string, bool) {
	u, err := url.Parse(strings.TrimSpace(base))
	if err != nil || u.Host == "" {
		return "", false
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return "", false
	}
	u.Path = strings.TrimRight(u.Path, "/")
	u.RawQuery = ""
	u.Fragment = ""
	return u.String(), true
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
