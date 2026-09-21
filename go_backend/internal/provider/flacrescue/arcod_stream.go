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
	"net/url"
	"strconv"
	"strings"
	"time"
)

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
		enlace, err := c.probarPuertaArcod(puerta, id, calidad, formato)
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
func (c *Client) probarPuertaArcod(p puertaArcod, id string, calidad int, formato string) (string, error) {
	cuerpo, err := c.pedirArcod(p.destino(c.baseArcodActiva(), id, calidad))
	if err != nil {
		return "", fmt.Errorf("arcod: el stream no se pudo pedir: %w (%s)", err, detalleSitio(cuerpo))
	}
	enlace, mime, err := p.leer(cuerpo)
	if err != nil {
		return "", err
	}
	if normalizarFormato(formato) == "FLAC" && mime != "" && !strings.HasPrefix(mime, "audio/flac") {
		return "", fmt.Errorf("arcod: el sitio degradó a %q, no es sin pérdida", mime)
	}
	return enlace, nil
}
