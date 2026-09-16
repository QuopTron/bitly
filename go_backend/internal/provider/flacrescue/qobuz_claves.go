// ─────────────────────────────────────────────────────────────
// qobuz_claves.go — Origen OPCIONAL de las claves del canal Qobuz
// firmado: en vez de pegar app_id/app_secret a mano, el usuario apunta a
// una URL que las publica y la app las refresca sola.
//
// Por qué existe: los app_secret de la API de Qobuz ROTAN. Un sitio que
// publica sus claves para su propio frontend (endpoint abierto, sin
// captcha) las cambia cada tanto, y con claves fijas el canal empezaría a
// devolver 400/401 hasta que el usuario las pegue de nuevo. Con el origen
// configurado, la app detecta ese 400/401, descarta lo cacheado y vuelve
// a firmar con las claves nuevas: se auto-cura.
//
// Qué NO hace: no resuelve captchas ni usa el carril de cuentas/cola de
// nadie. Es un GET a un JSON público; el audio sigue saliendo de la CDN de
// Qobuz, no del proveedor de las claves.
//
// Se conecta con: qobuz_ajustes.go (setting qobuz_keys_url) y
// qobuz_firmado.go (credencialesEfectivas / invalidarClaves).
// Parte del flujo: rescate de audio por ISRC.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// defaultKeysURLs son los orígenes de claves que la app prueba SOLA cuando el
// usuario no configuró ninguno. Es el punto del diseño: el usuario no tiene que
// pegar credenciales de nada — la app toma las claves públicas con las que
// cada sitio firma sus propias peticiones a Qobuz (endpoint abierto, sin
// captcha ni cuenta) y las refresca sola cuando rotan.
//
// Se prueban EN PARALELO y se VALIDAN contra Qobuz antes de usarlas, así un
// origen caído o con claves vencidas no rompe nada: simplemente se descarta y
// el canal queda apagado (los espejos y Soulseek siguen igual).
//
// El usuario puede reemplazarlos (o apagarlos) desde Ajustes → Credenciales:
// si pega su origen o su propio app_id/app_secret, eso manda.
var defaultKeysURLs = []string{
	"https://flacdownloader.com/api/qobuz/keys",
}

const (
	// ttlClaves es cuánto se recuerdan las claves del origen. Cinco minutos:
	// suficiente para no pedirlas en cada canción y corto para que una rotación
	// se resuelva sola en la siguiente reproducción.
	ttlClaves = 5 * time.Minute
	// timeoutClaves acota el pedido de claves: si el origen está caído, el
	// canal se apaga solo en esa resolución en vez de retrasarla.
	timeoutClaves = 4 * time.Second
)

// clavesQobuz es lo cacheado del origen de claves.
type clavesQobuz struct {
	appID   string
	secreto string
	hasta   time.Time
}

// errFirmaRechazada marca el 400/401 de Qobuz: la firma no validó, que es el
// síntoma de un app_secret rotado. Se distingue del resto de los fallos para
// poder reintentar UNA vez con claves frescas.
type errFirmaRechazada string

func (e errFirmaRechazada) Error() string { return string(e) }

// esFirmaRechazada reporta si [err] es un rechazo de firma.
func esFirmaRechazada(err error) bool {
	var r errFirmaRechazada
	return errors.As(err, &r)
}

// clavesDeOrigen resuelve {appId, appSecret} desde una lista de orígenes
// (separados por coma o salto de línea). Los prueba EN PARALELO y se queda con
// el primero que publique un par utilizable: con varios orígenes, la latencia
// es la del más rápido y uno caído no retrasa a los demás (misma política que
// los espejos de audio). Lo que se obtiene queda cacheado [ttlClaves].
func (c *Client) clavesDeOrigen(origenes string) (string, string, bool) {
	c.clavesMu.Lock()
	if c.claves.appID != "" && time.Now().Before(c.claves.hasta) {
		id, s := c.claves.appID, c.claves.secreto
		c.clavesMu.Unlock()
		return id, s, true
	}
	c.clavesMu.Unlock()

	urls := parseOrigenesClaves(origenes)
	if len(urls) == 0 {
		return "", "", false
	}

	type resultado struct {
		id      string
		secreto string
		valida  bool
	}
	canal := make(chan resultado, len(urls))
	for _, u := range urls {
		go func(url string) {
			id, secreto := c.pedirClavesA(url)
			// Se prueba contra Qobuz ANTES de darla por buena: un origen que
			// publica claves vencidas (el sitio todavía no las rotó, o publica
			// basura con forma de JSON) no puede ganar la carrera y envenenar el
			// canal con un par que hace fallar cada reproducción.
			canal <- resultado{id, secreto, id != "" && secreto != "" && c.clavesValidas(id, secreto)}
		}(u)
	}

	// Respaldo: un par que se pudo leer pero no se pudo validar. Se usa solo si
	// NINGÚN origen dio claves válidas, así el comportamiento nunca empeora
	// respecto de confiar en el JSON.
	var respaldo [2]string
	for rango := 0; rango < len(urls); rango++ {
		r := <-canal
		if r.id == "" || r.secreto == "" {
			continue
		}
		if !r.valida {
			if respaldo[0] == "" {
				respaldo = [2]string{r.id, r.secreto}
			}
			continue
		}
		c.guardarClaves(r.id, r.secreto)
		return r.id, r.secreto, true
	}
	if respaldo[0] != "" {
		c.guardarClaves(respaldo[0], respaldo[1])
		return respaldo[0], respaldo[1], true
	}
	return "", "", false
}

// guardarClaves cachea el par resuelto por [ttlClaves].
func (c *Client) guardarClaves(appID, secreto string) {
	c.clavesMu.Lock()
	c.claves = clavesQobuz{appID: appID, secreto: secreto, hasta: time.Now().Add(ttlClaves)}
	c.clavesMu.Unlock()
}

// clavesValidas comprueba el par contra Qobuz con una búsqueda firmada mínima:
// 200 = la firma es aceptada. Cuesta UNA petición por refresco de claves (cada
// 5 minutos como mucho) y evita que una fuente muerta deje el canal inútil.
func (c *Client) clavesValidas(appID, secreto string) bool {
	base, _, _, _, _, _ := c.qobuzConfig()
	ctx, cancel := context.WithTimeout(context.Background(), presupuestoQobuz)
	defer cancel()

	params := map[string]string{"query": "flac", "limit": "1", "offset": "0"}
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, urlFirmada(base, "/catalog/search", params, appID, secreto, ts), nil)
	if err != nil {
		return false
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}

// pedirClavesA hace UN pedido de claves. Acepta appId/appSecret y también los
// nombres en snake_case, porque varios orígenes copian el mismo contrato con
// otra ortografía.
func (c *Client) pedirClavesA(url string) (string, string) {
	ctx, cancel := context.WithTimeout(context.Background(), timeoutClaves)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return "", ""
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return "", ""
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return "", ""
	}
	var payload struct {
		AppID        string `json:"appId"`
		Secreto      string `json:"appSecret"`
		AppIDSnake   string `json:"app_id"`
		SecretoSnake string `json:"app_secret"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return "", ""
	}
	return primeroNoVacio(payload.AppID, payload.AppIDSnake), primeroNoVacio(payload.Secreto, payload.SecretoSnake)
}

// parseOrigenesClaves acepta "https://a,https://b" (o saltos de línea) y filtra
// lo que no sea una URL. Si el usuario no dejó ninguna, devuelve los orígenes
// por defecto: así el canal funciona recién instalado, sin pedirle nada.
func parseOrigenesClaves(raw string) []string {
	campos := strings.FieldsFunc(raw, func(r rune) bool {
		return r == ',' || r == '\n' || r == '\r' || r == ' '
	})
	limpios := make([]string, 0, len(campos))
	vistos := map[string]bool{}
	for _, u := range campos {
		u = strings.TrimSpace(u)
		if !strings.HasPrefix(u, "http") || vistos[u] {
			continue
		}
		vistos[u] = true
		limpios = append(limpios, u)
	}
	if len(limpios) == 0 {
		return append([]string(nil), defaultKeysURLs...)
	}
	return limpios
}

// invalidarClaves descarta lo cacheado para forzar un pedido nuevo (rotación).
func (c *Client) invalidarClaves() {
	c.clavesMu.Lock()
	c.claves = clavesQobuz{}
	c.clavesMu.Unlock()
}

// primeroNoVacio devuelve el primer valor no vacío (sin espacios).
func primeroNoVacio(valores ...string) string {
	for _, v := range valores {
		if t := strings.TrimSpace(v); t != "" {
			return t
		}
	}
	return ""
}
