// ─────────────────────────────────────────────────────────────
// sitios_flac.go — Registro de SITIOS RASPABLES de FLAC: webs que
// entregan un FLAC real sin cuenta, sin captcha y sin dar datos, con un
// protocolo propio (no el contrato /track/?isrc= de los espejos).
//
// Por qué existe: los espejos con contrato (dzr.tabs-vs-spaces.wtf) se
// quedaron sin cuentas vivas y el canal Qobuz firmado devuelve una
// MUESTRA de 30 s sin token de suscriptor. Los sitios son hoy la única
// puerta abierta al sin pérdida, y van en su propio registro y no mezclados
// con los espejos. El protocolo (superflac) lo comparten MUCHAS instancias: por
// eso el ajuste "sitios" acepta URLs nuevas y no solo las de fábrica.
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
	"fmt"
	"strings"
	"time"
)

const (
	// presupuestoSitios acota la carrera entre sitios: es el techo compartido de
	// la fase entera (búsqueda + trabajo + enlace firmado de CADA sitio) y existe
	// para que un sitio colgado no deje la descarga esperando sin fin. Con los
	// sitios en paralelo el tiempo real es el del MÁS RÁPIDO (~3s medidos), así
	// que la holgura solo cubre al que va bien cuando otro se cuelga.
	presupuestoSitios = 45 * time.Second
)

// errSinCoincidencia es el error de los sitios cuando ninguno de sus
// resultados coincide con la canción pedida (lo típico cuando el ISRC no
// existe en ningún catálogo y el sitio responde con búsqueda aproximada).
var errSinCoincidencia = errors.New("sin coincidencia verificable")

// errSitioSinCuentas lo devuelve un sitio cuando avisa que su pool de
// credenciales quedó sin cuentas vivas (arcod vive de tokens de Qobuz
// propios). Con eso el canal lo marca y lo saltea unos minutos en vez de
// pagar su espera completa en cada canción.

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
	return c.carreraSitios(c.listaSitios(), isrc, titulo, artista, durMS, formato, time.Now().Add(presupuestoSitios))
}

// resultadoSitio es lo que devuelve un sitio en la carrera: el enlace firmado
// (o vacío) y el error que explica por qué no lo dio.
type resultadoSitio struct {
	url    string
	nombre string
	err    error
}

// carreraSitios consulta TODOS los sitios habilitados A LA VEZ y devuelve el
// primero que entrega un enlace.
//
// Por qué en paralelo: cada sitio cuesta ~3s buenos y hasta 25s si encola el
// trabajo, así que en serie con varios sitios el tiempo era la SUMA y la
// descarga se hacía eterna. En paralelo es el del MÁS RÁPIDO, que es lo que
// importa cuando el usuario está esperando su FLAC.
//
// Un error de match (errSinCoincidencia) se recuerda y se prefiere al de tiempo
// agotado: "ningún sitio tiene esa canción" es más útil que "se acabó el
// tiempo". Los intentos que quedan en vuelo se descartan solos (el canal tiene
// capacidad para todos, así que ninguna goroutine queda colgada). [fin] es el
// vencimiento del presupuesto compartido, inyectable para poder probar el tope
// sin esperar los 45s reales.
func (c *Client) carreraSitios(sitios []sitioFLAC, isrc, titulo, artista string, durMS int, formato string, fin time.Time) (string, string, error) {
	if len(sitios) == 0 {
		return "", "", errors.New("sin sitios raspables habilitados")
	}
	canal := make(chan resultadoSitio, len(sitios))
	for _, sitio := range sitios {
		sitio := sitio
		go func() {
			defer func() {
				// Un sitio que paniquea no puede tumbar la descarga ni dejar el
				// canal sin respuesta.
				if r := recover(); r != nil {
					canal <- resultadoSitio{nombre: sitio.nombre(), err: fmt.Errorf("el sitio %s falló: %v", sitio.nombre(), r)}
				}
			}()
			u, err := sitio.resolver(isrc, titulo, artista, durMS, formato)
			canal <- resultadoSitio{url: u, nombre: sitio.nombre(), err: err}
		}()
	}

	limite := time.NewTimer(time.Until(fin))
	defer limite.Stop()

	var ultimo, problema error
	for rango := 0; rango < len(sitios); rango++ {
		select {
		case r := <-canal:
			if r.err == nil && r.url != "" {
				return r.url, r.nombre, nil
			}
			if r.err != nil {
				ultimo = r.err
				if errors.Is(r.err, errSinCoincidencia) {
					problema = r.err
				}
			}
		case <-limite.C:
			if problema != nil {
				return "", "", problema
			}
			if ultimo == nil {
				ultimo = errors.New("tiempo agotado")
			}
			return "", "", ultimo
		}
	}
	if problema != nil {
		return "", "", problema
	}
	if ultimo == nil {
		ultimo = errors.New("sin respuesta de los sitios")
	}
	return "", "", ultimo
}
