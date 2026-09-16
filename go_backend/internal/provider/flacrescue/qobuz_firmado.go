// ─────────────────────────────────────────────────────────────
// qobuz_firmado.go — Canal "Qobuz firmado": convierte un ISRC en la
// URL de CDN de Qobuz (FLAC sin pérdida) con una petición FIRMADA.
//
// Por qué existe: es el mecanismo REAL con el que un sitio de
// descarga entrega FLAC de Qobuz sin cuentas propias de cada usuario
// (auditado en flacdownloader.com: /catalog/search y
// /track/getFileUrl contra la API pública de Qobuz con app_id +
// app_secret + firma MD5). Su valor, comparado con los espejos:
//
//   - devuelve una URL de CDN DIRECta y con rangos: el reproductor
//     suena al instante, sin bajar el archivo ni descifrarlo ni
//     escribirlo en disco (los espejos suelen entregar el binario);
//   - resuelve por IDENTIDAD (el ISRC), no por parecido de nombre.
//
// Lo que NO hace: no inventa credenciales ni resuelve captchas. El
// app_id/app_secret los configura el usuario (o un espejo propio que
// los exponga) en Ajustes → Credenciales. Sin credenciales el canal
// queda apagado y todo sigue igual que antes (espejos).
//
// Se conecta con: client.go (configuración) y resolucion.go (lo
// intenta antes de la cascada de espejos cuando hay credenciales).
// Parte del flujo: rescate de audio por ISRC (reproducción y descarga).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"context"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	// qobuzAPIBasePorDefecto es la API pública de Qobuz (configurable
	// para apuntar a un proxy propio).
	qobuzAPIBasePorDefecto = "https://www.qobuz.com/api.json/0.2"
	// qobuzFormatoFLAC es el format_id que Qobuz usa para servir el
	// stream sin pérdida (el mismo valor que usa el sitio auditado).
	qobuzFormatoFLAC = "5"
	// presupuestoQobuz acota el canal ENTERO (búsqueda + URL): es la
	// primera fase de la resolución, así que no puede comerse el
	// presupuesto total de los espejos.
	presupuestoQobuz = 2500 * time.Millisecond
	// maxPistasQobuz acota la búsqueda por ISRC (la primera coincidencia
	// exacta gana; pedir más solo alarga la respuesta).
	maxPistasQobuz = 5
)

// firmaQobuz reproduce el esquema de firma de Qobuz:
//
//	MD5( metodoSinBarras + "clavevalor" de los params ORDENADOS + ts + secreto )
//
// El nombre del método es la ruta sin la barra ("track/getFileUrl" →
// "trackgetFileUrl"), y la firma solo cubre los parámetros propios del
// método: app_id, request_ts y request_sig van en la URL pero NO en el
// texto firmado (si entraran, la firma nunca validaría).
func firmaQobuz(metodo string, params map[string]string, ts, secreto string) string {
	claves := make([]string, 0, len(params))
	for k := range params {
		claves = append(claves, k)
	}
	sort.Strings(claves)

	var texto strings.Builder
	texto.WriteString(metodo)
	for _, k := range claves {
		texto.WriteString(k)
		texto.WriteString(params[k])
	}
	texto.WriteString(ts)
	texto.WriteString(secreto)

	suma := md5.Sum([]byte(texto.String()))
	return hex.EncodeToString(suma[:])
}

// qobuzConfig lee la configuración del canal SIN tocar la red. Va aparte de
// credencialesEfectivas porque conseguir las claves puede costar una petición,
// y ahí el candado de la configuración no puede estar tomado.
func (c *Client) qobuzConfig() (base, token, formato, keysURL, appID, secreto string) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	base = strings.TrimRight(c.qobuzBase, "/")
	if base == "" {
		base = qobuzAPIBasePorDefecto
	}
	formato = c.qobuzFormato
	if formato == "" {
		formato = qobuzFormatoFLAC
	}
	return base, c.qobuzToken, formato, strings.TrimSpace(c.qobuzKeysURL), c.qobuzAppID, c.qobuzSecreto
}

// credencialesEfectivas resuelve app_id/app_secret: mandan las que el usuario
// pegó a mano; si no hay, se piden al origen de claves (el suyo si configuró
// uno; si no, el que la app trae de fábrica — ver defaultKeysURLs).
// [ok] false = no se consiguió ningún par válido.
func (c *Client) credencialesEfectivas() (appID, secreto string, ok bool) {
	_, _, _, keysURL, estaticoID, estaticoSecreto := c.qobuzConfig()
	if estaticoID != "" && estaticoSecreto != "" {
		return estaticoID, estaticoSecreto, true
	}
	return c.clavesDeOrigen(keysURL)
}

// qobuzCredenciales devuelve la configuración del canal ya resuelta.
func (c *Client) qobuzCredenciales() (base, appID, secreto, token, formato string, ok bool) {
	base, token, formato, _, _, _ = c.qobuzConfig()
	appID, secreto, ok = c.credencialesEfectivas()
	return
}

// pedirQobuz firma y ejecuta UNA llamada del canal. Devuelve el JSON ya
// decodificado en [destino].
//
// Reintenta UNA vez cuando Qobuz responde 400/401 (firma rechazada) y las
// claves vienen de un origen externo: ese 400/401 es el síntoma EXACTO de que el
// proveedor rotó su app_secret, así que se refresca el origen y se vuelve a
// firmar. Es la misma política que usa el frontend del sitio auditado.
func (c *Client) pedirQobuz(ctx context.Context, base, ruta string, params map[string]string, destino any) error {
	_, _, _, keysURL, _, _ := c.qobuzConfig()
	for intento := 0; ; intento++ {
		if err := c.unaLlamadaQobuz(ctx, base, ruta, params, destino); err == nil {
			return nil
		} else if !esFirmaRechazada(err) {
			return err
		} else if keysURL == "" || intento >= 1 {
			return err
		}
		// Rotación de claves: se descarta lo cacheado y se reintenta con las
		// nuevas. Solo una vez, para no entrar en un bucle de reintentos.
		c.invalidarClaves()
	}
}

// urlFirmada arma la URL de una llamada firmada: los parámetros propios del
// método + app_id + request_ts + request_sig. Va aparte para que la validación
// de claves (qobuz_claves.go) firme EXACTAMENTE igual que las llamadas reales.
func urlFirmada(base, ruta string, params map[string]string, appID, secreto, ts string) string {
	q := url.Values{}
	for k, v := range params {
		q.Set(k, v)
	}
	q.Set("app_id", appID)
	q.Set("request_ts", ts)
	q.Set("request_sig", firmaQobuz(strings.ReplaceAll(ruta, "/", ""), params, ts, secreto))
	return base + ruta + "?" + q.Encode()
}

// unaLlamadaQobuz hace la petición firmada (un solo intento).
func (c *Client) unaLlamadaQobuz(ctx context.Context, base, ruta string, params map[string]string, destino any) error {
	_, appID, secreto, token, _, ok := c.qobuzCredenciales()
	if !ok {
		return fmt.Errorf("qobuz-firmado: sin credenciales")
	}
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	consulta := urlFirmada(base, ruta, params, appID, secreto, ts)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, consulta, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")
	if token != "" {
		// El token de usuario va por CABECERA: agregarlo como parámetro
		// rompería la firma (no está firmado).
		req.Header.Set("X-User-Auth-Token", token)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("qobuz-firmado: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusBadRequest || resp.StatusCode == http.StatusUnauthorized {
		return errFirmaRechazada(fmt.Sprintf("qobuz-firmado (%d) en %s", resp.StatusCode, ruta))
	}
	if resp.StatusCode >= 400 {
		return fmt.Errorf("qobuz-firmado (%d) en %s", resp.StatusCode, ruta)
	}
	if err := json.NewDecoder(resp.Body).Decode(destino); err != nil {
		return fmt.Errorf("qobuz-firmado: respuesta no interpretada en %s", ruta)
	}
	return nil
}
