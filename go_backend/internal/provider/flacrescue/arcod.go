// ─────────────────────────────────────────────────────────────
// arcod.go — Canal arcod: convierte un ISRC en el enlace de un FLAC REAL
// que se puede REPRODUCIR y descargar, sin cuenta y sin captcha.
//
// Qué es: arcod.xyz es un descargador de Qobuz, y su catálogo responde
// como invitado (comprobado: /api/v2/guest/rate-limit da limit=999999
// sin sesión). Su lector de audio —el que alimenta su propio
// reproductor— entrega el archivo de Qobuz con estas tres cosas, que es
// justo lo que faltaba:
//   · es el FLAC completo (medido con ffprobe: 183,7 s, 1,64 Mbps),
//     nunca una muestra de 30 s;
//   · soporta Range (206 Partial Content + accept-ranges), así que se
//     reproduce EN VIVO sin bajar la canción entera antes;
//   · el enlace se puede volver a pedir (no es de un solo uso), así que
//     la descarga puede sondear y reanudar.
//
// Cómo se resuelve (dos peticiones, ~1,5 s en total):
//  1. GET /api/get-music?q=<ISRC>&offset=0  → la pista del ISRC
//  2. GET /api/player/stream/<id>?quality=N → {url, mimeType}
//
// La calidad se pide en 6 (FLAC 16/44.1): el mismo tema en 24/96 entrega
// 37,6 MB contra 21,4 MB, y un stream tiene que sostener ese caudal
// mientras suena. La app no distingue "sin pérdida" de "hi-res", así que
// se elige la que garantiza reproducción fluida.
//
// AVISO: el sitio vive de un pool de tokens de Qobuz propio; cuando se
// queda vacío contesta "No healthy Qobuz tokens available" y su catálogo
// entero cae. El canal lo detecta, se marca y se saltea unos minutos en
// vez de pagar la espera en cada reproducción.
//
// Se conecta con: resolucion.go (canal de GetStreamURL, antes de los
// espejos), arcod_catalogo.go (lectura) y arcod_memoria.go (caché).
// Parte del flujo: rescate de FLAC por stream y por descarga.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"errors"
	"fmt"
	"log"
	"net/url"
	"time"
)

const (
	baseArcod   = "https://arcod.xyz"
	nombreArcod = "arcod"

	// presupuestoArcod acota lo que el canal puede tardar entre sus dos
	// peticiones: entra en la fase exacta del rescate (3 s de ventana), así
	// que no puede quedarse con el turno.
	presupuestoArcod = 4 * time.Second
	// ttlArcods es lo que se recuerda un enlace firmado. El token vive al
	// menos 5 minutos (medido); pasado ese rato se vuelve a pedir, que es una
	// petición y evita que el reproductor reciba uno vencido.
	ttlArcods = 5 * time.Minute
)

// errArcodSinCuentas lo devuelve el canal cuando el sitio avisa que su pool de
// tokens de Qobuz quedó sin cuentas vivas. No es fatal: el canal se saltea
// unos minutos y el resto del rescate sigue igual.
var errArcodSinCuentas = errors.New("arcod: el sitio se quedó sin cuentas")

// errArcodApagado lo devuelve el canal cuando un ajuste lo apagó. El rescate lo
// trata como "esta fuente no aporta", igual que un sitio raspable apagado.
var errArcodApagado = errors.New("arcod: canal apagado")

// arcodPorDefecto dice si el canal arranca encendido. Es una variable por el
// mismo motivo que los orígenes de claves de Qobuz: los tests del paquete son
// offline por contrato y lo apagan en TestMain.
var arcodPorDefecto = true

// resolverArcod resuelve un ISRC al enlace del FLAC del sitio. [formato] es el
// formato pedido por el backend (FLAC | MP3_320 | MP3_128).
func (c *Client) resolverArcod(isrc, formato string) (string, error) {
	clave := normalizarISRC(isrc)
	if clave == "" {
		return "", errSinCoincidencia
	}
	if !c.arcodEncendido() {
		return "", errArcodApagado
	}
	// En pausa (pool muerto) o sin presupuesto de invitado: no se gasta ni una
	// petición. Ver arcod_cuota.go.
	if c.enPausaArcod() {
		return "", errArcodSinCuentas
	}
	if err := c.cuotaArcodSuficiente(); err != nil {
		c.marcarSiSinCuentas(err)
		return "", err
	}
	inicio := time.Now()
	fin := inicio.Add(presupuestoArcod)
	id, err := c.idPistaArcod(clave, fin)
	if err != nil {
		c.marcarSiSinCuentas(err)
		log.Printf("[arcod] ISRC %s sin resolver: %v", clave, err)
		return "", err
	}
	enlace, err := c.enlaceStreamArcod(id, formato, fin)
	if err != nil {
		c.marcarSiSinCuentas(err)
		log.Printf("[arcod] ISRC %s (id=%s) sin enlace: %v", clave, id, err)
		return "", err
	}
	// Una línea por resolución: sin esto no hay forma de distinguir en el log
	// si el FLAC vino de este canal o de los espejos (ambos reportan
	// "flac-rescue" como proveedor).
	log.Printf("[arcod] ISRC %s -> FLAC del catálogo en %dms (%s, id=%s)",
		clave, time.Since(inicio).Milliseconds(), formato, id)
	c.marcarAciertoArcod()
	return enlace, nil
}

// marcarSiSinCuentas pone el canal en pausa cuando el fallo fue del pool del
// sitio (o de su presupuesto), para no volver a pagar la espera en cada
// canción. La pausa crece con los fallos seguidos y se borra al primer acierto
// (ver arcod_cuota.go).
func (c *Client) marcarSiSinCuentas(err error) {
	if errors.Is(err, errArcodSinCuentas) || errors.Is(err, errArcodSinCuota) {
		c.marcarFalloArcod()
	}
}

// idPistaArcod busca el ISRC en el catálogo del sitio y devuelve el id de la
// pista que coincide. El id se memoriza (ver arcod_memoria.go): es estable y
// ahorra una petición en cada reproducción.
func (c *Client) idPistaArcod(isrc string, fin time.Time) (string, error) {
	if id := c.idArcodGuardado(isrc); id != "" {
		return id, nil
	}
	if time.Now().After(fin) {
		return "", errors.New("arcod: sin tiempo para buscar en el catálogo")
	}
	destino := c.baseArcodActiva() + "/api/get-music?" + url.Values{
		"q":      {isrc},
		"offset": {"0"},
	}.Encode()
	cuerpo, err := c.pedirArcod(destino)
	if err != nil {
		return "", fmt.Errorf("arcod: la búsqueda falló: %w (%s)", err, detalleSitio(cuerpo))
	}
	pistas, err := pistasArcod(cuerpo)
	if err != nil {
		return "", err
	}
	pista, err := pistaArcodPorISRC(pistas, isrc)
	if err != nil {
		return "", err
	}
	c.guardarIDArcod(isrc, pista.idArcod())
	return pista.idArcod(), nil
}

// El enlace del stream se pide en arcod_stream.go: hay más de una puerta
// conocida (la pública no documenta la suya) y allí se elige y se memoriza.
