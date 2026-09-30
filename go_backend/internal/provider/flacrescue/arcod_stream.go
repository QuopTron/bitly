// ─────────────────────────────────────────────────────────────
// arcod_stream.go — Puertas del enlace de audio del canal arcod.
//
// Por qué hay más de una: la ruta del reproductor que usa la
// instancia PÚBLICA no está en el repo abierto, así que una
// instancia PROPIA (o el día que renombren esa ruta) puede
// exponerla en otro lado. Acá se prueban las puertas conocidas,
// se recuerda la que funcionó y las canciones siguientes pagan
// UNA sola petición.
//
//	/api/player/stream/<id>?quality=N  → {url,mimeType}  (la pública)
//	/v2/stream/<id>?quality=N          → {url,mimeType}  (servidor del repo)
//	/api/get-track-url?track_id=<id>   → {success,url}   (ruta legacy, MP3)
//
// Se conecta con: arcod.go (resolución), arcod_json.go (Bearer) y
// arcod_memoria.go (calidad).
// Parte del flujo: rescate de FLAC por stream y por descarga.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// timeoutComprobarEnlace es el techo de la comprobación del enlace firmado. Es
// una petición MÍNIMA (Range de un byte), así que un segundo sobra; 2s deja aire
// para redes lentas sin comerse el presupuesto del canal.
const timeoutComprobarEnlace = 2 * time.Second

// comprobarEnlaceArcod es la comprobación que se le hace al enlace antes de
// entregarlo. Es una variable por dos motivos: los tests del paquete son
// offline por contrato (TestMain la sustituye) y una instancia PROPIA con un
// lector distinto puede reemplazarla. Ver enlaceArcodSirveAudio.
var comprobarEnlaceArcod = enlaceArcodSirveAudio

// enlaceArcodSirveAudio comprueba que el enlace firmado SIRVA audio de verdad
// antes de que el reproductor lo reciba.
//
// Por qué existe: el sitio empezó a devolver enlaces a OTRO host
// (api.arcod.xyz/v2/stream/play?t=…) que a veces contesta 502. El canal
// entregaba ese enlace igual, y el síntoma era "la canción no reproduce" en
// cualquier fuente que cayera en el rescate (medido: un toque desde el feed de
// Amazon terminaba con un 502 en la mano). Comprobar con una petición de un
// byte lo detecta en el momento, y el rescate sigue con las otras fuentes en vez
// de dejar al usuario sin audio.
//
// Un fallo de RED al comprobar NO invalida el enlace (puede ser ruido del
// sondeo); lo que invalida es una RESPUESTA de error del servidor, que es
// evidencia directa de que el enlace no sirve.
func enlaceArcodSirveAudio(enlace string, fin time.Time) error {
	if enlace == "" {
		return errors.New("arcod: enlace vacío")
	}
	tope := timeoutComprobarEnlace
	if restante := time.Until(fin); restante > 0 && restante < tope {
		tope = restante
	}
	req, err := http.NewRequest(http.MethodGet, enlace, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Range", "bytes=0-0")
	req.Header.Set("User-Agent", userAgent)
	// Transporte COMPARTIDO del paquete (proxy.go): la comprobación sale por el
	// proxy del rescate como el resto de sus peticiones. El enlace apunta a OTRO
	// host (api.arcod.xyz), así que sin esto la comprobación salía directa y un
	// ajuste de proxy por región dejaba al canal creyendo que el enlace no sirve.
	// De paso reusa las conexiones ya abiertas en vez de armar un cliente nuevo
	// por comprobación (una por canción).
	resp, err := (&http.Client{Timeout: tope, Transport: transporteRescateContado}).Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 1))
	if resp.StatusCode >= http.StatusBadRequest {
		return fmt.Errorf("arcod: el enlace no sirve audio (%d)", resp.StatusCode)
	}
	return nil
}

// puertaArcod es una forma de pedir el enlace de audio: cómo se arma la
// petición y cómo se lee la respuesta.
type puertaArcod struct {
	nombre  string
	destino func(base, id string, calidad int) string
	// leer devuelve la URL del audio y su tipo MIME (vacío = la puerta no lo
	// declara, y entonces no se puede exigir sin pérdida).
	leer func(cuerpo []byte) (string, string, error)
}

// puertasArcod son las puertas conocidas, en orden de preferencia: la que usa
// la instancia pública va primero porque es la que entrega FLAC hoy.
var puertasArcod = []puertaArcod{
	{
		nombre:  "player",
		destino: destinoConCalidad("/api/player/stream/"),
		leer:    leerURLConMime,
	},
	{
		nombre:  "servidor",
		destino: destinoConCalidad("/v2/stream/"),
		leer:    leerURLConMime,
	},
	{
		nombre: "legacy",
		destino: func(base, id string, _ int) string {
			return base + "/api/get-track-url?" + url.Values{"track_id": {id}}.Encode()
		},
		// La ruta legacy del repo pide MP3 320 a la fuerza y no dice el MIME:
		// se declara tal cual para que un pedido sin pérdida no la acepte.
		leer: func(cuerpo []byte) (string, string, error) {
			var respuesta struct {
				URL string `json:"url"`
			}
			if err := json.Unmarshal(cuerpo, &respuesta); err != nil || !esURLDeAudio(respuesta.URL) {
				return "", "", fmt.Errorf("arcod: sin enlace de audio: %s", detalleSitio(cuerpo))
			}
			return respuesta.URL, "audio/mpeg", nil
		},
	},
}

// destinoConCalidad arma la ruta de una puerta que pide la calidad por query.
func destinoConCalidad(ruta string) func(base, id string, calidad int) string {
	return func(base, id string, calidad int) string {
		return base + ruta + url.PathEscape(id) + "?" +
			url.Values{"quality": {strconv.Itoa(calidad)}}.Encode()
	}
}

// leerURLConMime lee la respuesta de las puertas que devuelven {url,mimeType}.
func leerURLConMime(cuerpo []byte) (string, string, error) {
	var respuesta struct {
		URL      string `json:"url"`
		MimeType string `json:"mimeType"`
	}
	if err := json.Unmarshal(cuerpo, &respuesta); err != nil {
		return "", "", fmt.Errorf("arcod: respuesta ilegible: %s", detalleSitio(cuerpo))
	}
	if !esURLDeAudio(respuesta.URL) {
		return "", "", fmt.Errorf("arcod: sin enlace de audio: %s", detalleSitio(cuerpo))
	}
	return respuesta.URL, respuesta.MimeType, nil
}

// esURLDeAudio dice si el enlace recibido es una URL http(s) utilizable.
func esURLDeAudio(enlace string) bool {
	return strings.HasPrefix(enlace, "http://") || strings.HasPrefix(enlace, "https://")
}

// puertaArcodGuardada devuelve la puerta que funcionó por última vez (vacía =
// todavía no se probó ninguna).
func (c *Client) puertaArcodGuardada() string {
	c.puertaArcodMu.Lock()
	defer c.puertaArcodMu.Unlock()
	return c.puertaArcod
}

// recordarPuertaArcod memoriza la puerta ganadora: la próxima canción paga una
// sola petición en vez de volver a probar.
func (c *Client) recordarPuertaArcod(nombre string) {
	c.puertaArcodMu.Lock()
	defer c.puertaArcodMu.Unlock()
	c.puertaArcod = nombre
}

// olvidarPuertaArcod borra la puerta memorizada (la instancia cambió de
// dirección: la de antes ya no dice nada de esta).
func (c *Client) olvidarPuertaArcod() {
	c.puertaArcodMu.Lock()
	defer c.puertaArcodMu.Unlock()
	c.puertaArcod = ""
}

// enlaceStreamArcod pide el enlace firmado del archivo de [id], probando las
// puertas conocidas con el presupuesto que queda. La primera que entregue audio
// del formato pedido gana y queda memorizada.
func (c *Client) enlaceStreamArcod(id, formato string, fin time.Time) (string, error) {
	if time.Now().After(fin) {
		return "", errors.New("arcod: sin tiempo para pedir el stream")
	}
	calidad := calidadArcodStream(formato)
	var ultimo error
	for _, puerta := range c.puertasArcodAProbar() {
		if time.Now().After(fin) {
			break
		}
		enlace, err := c.probarPuertaArcod(puerta, id, calidad, formato, fin)
		if err != nil {
			ultimo = err
			continue
		}
		c.recordarPuertaArcod(puerta.nombre)
		return enlace, nil
	}
	if ultimo == nil {
		ultimo = errors.New("arcod: sin tiempo para probar las puertas del stream")
	}
	return "", ultimo
}

// puertasArcodAProbar devuelve la puerta memorizada (si hay) o todas, en orden.
func (c *Client) puertasArcodAProbar() []puertaArcod {
	if nombre := c.puertaArcodGuardada(); nombre != "" {
		for _, puerta := range puertasArcod {
			if puerta.nombre == nombre {
				return []puertaArcod{puerta}
			}
		}
	}
	return puertasArcod
}

// probarPuertaArcod hace la petición de una puerta y valida la respuesta: un
// pedido sin pérdida que vuelve en MP3 es una degradación, y se falla a
// propósito para que las fuentes que sí pueden dar FLAC conserven su turno.
//
// El último control es el del ENLACE: que entregue audio de verdad, no un 502
// del CDN (ver enlaceArcodSirveAudio). Sin él, el enlace muerto se cacheaba 5
// minutos y el reproductor no tenía forma de sonar.
func (c *Client) probarPuertaArcod(p puertaArcod, id string, calidad int, formato string, fin time.Time) (string, error) {
	cuerpo, err := c.pedirArcod(p.destino(c.baseArcodActiva(), id, calidad))
	if err != nil {
		err = clasificarFalloArcod(err, cuerpo)
		return "", fmt.Errorf("arcod: el stream no se pudo pedir: %w (%s)", err, detalleSitio(cuerpo))
	}
	enlace, mime, err := p.leer(cuerpo)
	if err != nil {
		return "", err
	}
	if normalizarFormato(formato) == "FLAC" && mime != "" && !strings.HasPrefix(mime, "audio/flac") {
		return "", fmt.Errorf("arcod: el sitio degradó a %q, no es sin pérdida", mime)
	}
	if err := comprobarEnlaceArcod(enlace, fin); err != nil {
		return "", err
	}
	return enlace, nil
}
