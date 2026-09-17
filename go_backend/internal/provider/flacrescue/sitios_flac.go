// ─────────────────────────────────────────────────────────────
// sitios_flac.go — Registro de SITIOS RASPABLES de FLAC: webs que
// entregan un FLAC real sin cuenta, sin captcha y sin dar datos, con un
// protocolo propio (no el contrato /track/?isrc= de los espejos).
//
// Por qué existe: los espejos con contrato (dzr.tabs-vs-spaces.wtf) se
// quedaron sin cuentas vivas y el canal Qobuz firmado devuelve una
// MUESTRA de 30 s sin token de suscriptor. Los sitios son hoy la única
// puerta abierta al sin pérdida, y cada uno habla distinto, así que van
// en su propio registro y no mezclados con los espejos.
//
// Se usan SOLO para descargar (los enlaces no soportan Range) y su
// resultado pasa por la verificación de match de sitios_flac_analisis.go
// antes de bajar un solo byte.
//
// Se conecta con: orchestrator_mejora_flac.go (download) vía
// ResolverSitioFLAC, y extensions_settings.go (ajuste "sitios").
// Parte del flujo: rescate de FLAC por descarga.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"errors"
	"strings"
)

// errSinCoincidencia es el error de los sitios cuando ninguno de sus
// resultados coincide con la canción pedida (lo típico cuando el ISRC no
// existe en ningún catálogo y el sitio responde con búsqueda aproximada).
var errSinCoincidencia = errors.New("sin coincidencia verificable")

// sitioFLAC es un sitio raspable con protocolo propio.
type sitioFLAC interface {
	nombre() string
	base() string
	// resolver devuelve el enlace del archivo sin pérdida para una pista ya
	// identificada (ISRC + título + artista + duración del catálogo).
	resolver(isrc, titulo, artista string, durMS int, formato string) (string, error)
}

// sitiosConocidos son los sitios habilitados por defecto, en orden de intento.
var sitiosConocidos = []sitioFLAC{nuevoSitioSuperflac()}

// listaSitios devuelve una copia de los sitios habilitados.
func (c *Client) listaSitios() []sitioFLAC {
	c.sitiosMu.RLock()
	defer c.sitiosMu.RUnlock()
	return append([]sitioFLAC(nil), c.sitios...)
}

// ResolverSitioFLAC busca el FLAC real de una pista en los sitios raspables y
// devuelve el enlace firmado junto con el nombre del sitio que lo entregó.
//
// SOLO PARA DESCARGAR: los enlaces son el archivo completo y no soportan
// peticiones por rango, así que usarlos como stream obligaría a bajar el
// álbum entero antes de oír el primer segundo.
//
// Necesita el título y el artista del catálogo: son la única forma de
// confirmar que el sitio devolvió la canción pedida (busca por texto, no
// por ISRC).
func (c *Client) ResolverSitioFLAC(isrc, titulo, artista string, durMS int, formato string) (string, string, error) {
	if normalizarISRC(isrc) == "" {
		return "", "", errNoCatalogo("se requiere ISRC")
	}
	if strings.TrimSpace(titulo) == "" || strings.TrimSpace(artista) == "" {
		return "", "", errors.New("flac-rescue: los sitios necesitan título y artista para verificar el match")
	}
	var ultimo error
	var problema error
	for _, sitio := range c.listaSitios() {
		enlace, err := sitio.resolver(isrc, titulo, artista, durMS, formato)
		if err == nil && enlace != "" {
			return enlace, sitio.nombre(), nil
		}
		if err != nil {
			ultimo = err
			if errors.Is(err, errSinCoincidencia) {
				problema = err
			}
		}
	}
	if ultimo == nil {
		ultimo = errors.New("sin sitios raspables habilitados")
	}
	if problema != nil {
		return "", "", problema
	}
	return "", "", ultimo
}
