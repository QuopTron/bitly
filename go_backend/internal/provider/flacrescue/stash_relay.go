// ─────────────────────────────────────────────────────────────
// stash_relay.go — Canal "stash-relay": convierte el id de una pista
// de Qobuz en la URL de su FLAC por el relay público del proyecto
// Stash (rawnaldclark/Stash), sin cuenta propia.
//
// Por qué existe: el canal Qobuz firmado necesita credenciales de
// suscriptor para entregar FLAC de verdad (sin ellas Qobuz degrada a
// MP3, ver qobuz_archivo.go), y el canal arcod vive de un pool público
// que lleva vacío desde hace meses. Este relay es distinto: corre sobre
// un pool de cuentas PROPIAS de otro proyecto y publica, por petición
// FIRMADA, una URL de CDN de Qobuz ya autenticada y con rangos. Los
// bytes de audio NO pasan por el relay: la app los baja del CDN de
// Qobuz directo (el contrato lo exige, spec §4).
//
// Cómo se resuelve (dos peticiones, la primera cacheada 6 h):
//  1. GET <config>  → {relays:[{base,priority}], relay_key}  (config
//     firmada, servida por el Worker tipjar del proyecto).
//  2. GET <base>/v1/qobuz/file?track_id=<id>&format_id=<6|7|27> con
//     X-Stash-Version: 1, X-Stash-Install, X-Stash-Ts y X-Stash-Auth
//     = hex(HMAC-SHA256(relay_key, "<install>:<track_id>:<format_id>:<ts>"))
//     → 200 {url, format_id, bit_depth, sample_rate}.
//
// La URL se VALIDA antes de devolverla: tiene que ser https y traer su
// parámetro `etsp=<unix>`, que es de donde el reproductor deriva el
// vencimiento (~1 h). Una URL sin etsp haría fallar el stream en
// silencio, así que se rechaza (spec §1).
//
// AVISO honesto: es infraestructura de un tercero, dimensionada como
// "puente" (unos cientos de mints/día) y con cupos por IP e instalación.
// Puede cortarse o ponerse a firmar con otra clave cuando quiera. El
// canal lo trata como cualquier otra fuente: si falla, el rescate sigue
// con arcod, los espejos y los sitios. Se apaga con el ajuste
// `stash_relay` (ver stash_relay_ajustes.go).
//
// Se conecta con: resolucion.go (lo intenta antes de arcod) y client.go
// (configuración y estado).
// Parte del flujo: rescate de audio por ISRC.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	// nombreStashRelay es el nombre con el que el canal se reporta como
	// proveedor cuando gana la resolución.
	nombreStashRelay = "stash-relay"

	// stashConfigURLPorDefecto es la config firmada del relay, servida por el
	// Worker tipjar del proyecto (spec §3). Es una URL pública y por eso puede
	// vivir en el fuente; el relay_key que trae dentro cambia sin aviso, razón
	// por la que la config NO se hardcodea.
	stashConfigURLPorDefecto = "https://stash-tipjar.rawnaldclark.workers.dev/lossless.json"

	// stashFormatoFLAC es el format_id de Qobuz sin pérdida que se pide. Se
	// elige 6 (FLAC 16/44.1) y no 7/27 (hi-res) por la misma razón que arcod:
	// un stream tiene que sostener el caudal mientras suena, y la app no
	// distingue "sin pérdida" de "hi-res".
	stashFormatoFLAC = "6"

	// ttlStashConfig es cuánto se recuerda la config. Seis horas: el relay_key
	// rota muy de vez en cuando y la config es un GET barato, pero no vale la
	// pena pedirla en cada canción.
	ttlStashConfig = 6 * time.Hour
	// ttlStashEnlace es lo que se recuerda una URL ya minteada. El enlace vive
	// ~1 h (lo dice su `etsp`); cinco minutos garantizan que nunca se sirva uno
	// vencido.
	ttlStashEnlace = 5 * time.Minute
	// timeoutStash acota cada petición al relay. Se alineó con el cliente del
	// proyecto original (8 s de presupuesto): medido en el emulador, un arranque
	// en frío del Worker pasaba de 4 s y el canal perdía el FLAC por un techo
	// que el mint no llegaba a cruzar. En caliente tarda ~0,7 s, así que este
	// techo no se paga casi nunca; solo existe para no colgar el rescate.
	timeoutStash = 8 * time.Second
	// timeoutStashConfig es más generoso que el mint: es la PRIMERA petición
	// (TLS en frío a un Worker) y se paga una sola vez cada 6 h. El cliente
	// general del paquete usa 3 s, que medido se quedó corto en el arranque en
	// frío (ver stash_relay_red_test.go).
	timeoutStashConfig = 6 * time.Second
)

// stashRelayPorDefecto dice si el canal arranca encendido. Es una variable por
// el mismo motivo que arcodPorDefecto: los tests del paquete son offline por
// contrato y lo apagan en TestMain.
var stashRelayPorDefecto = true

// errStashApagado lo devuelve el canal cuando un ajuste lo apagó.
var errStashApagado = errors.New("stash-relay: canal apagado")

// errStashNoAutorizado marca el 401 del relay: la firma no validó, que es el
// síntoma de que rotó la clave del relay. Se distingue del resto de los fallos
// para poder recargar la config y reintentar UNA vez.
type errStashNoAutorizado string

func (e errStashNoAutorizado) Error() string { return string(e) }

// esStashNoAutorizado reporta si [err] es un 401 del relay.
func esStashNoAutorizado(err error) bool {
	var r errStashNoAutorizado
	return errors.As(err, &r)
}

// relayStash es la config cacheada del relay: dónde está y con qué clave firmar.
type relayStash struct {
	base  string
	clave string
	hasta time.Time
}

// etspStash reconoce el parámetro `etsp=<unix>` que Qobuz incrusta en su URL de
// CDN y del que el reproductor deriva el vencimiento.
var etspStash = regexp.MustCompile(`[?&]etsp=(\d+)`)

// resolverStashRelay resuelve un id de pista de Qobuz (numérico) o un ISRC a la
// URL de su FLAC por el relay. Un pedido CON pérdida devuelve error a
// propósito: el relay es solo sin pérdida y los espejos siguen teniendo la
// oportunidad.
func (c *Client) resolverStashRelay(id, formatoPedido string) (string, error) {
	if !c.stashEncendido() {
		return "", errStashApagado
	}
	formatID := formatoStash(formatoPedido)
	if formatID == "" {
		return "", fmt.Errorf("stash-relay: solo sirve sin pérdida")
	}
	inicio := time.Now()

	trackID := strings.TrimSpace(id)
	if !esIDNumerico(trackID) {
		// Un ISRC no le dice nada al relay: hay que traducirlo a un id de pista
		// de Qobuz. Eso necesita las claves del canal firmado (búsqueda por
		// texto + confirmación de ISRC), que son las mismas que ya se usan para
		// el canal Qobuz. Sin ellas, este canal no aporta.
		base, _, _, _, _, ok := c.qobuzCredenciales()
		if !ok {
			return "", fmt.Errorf("stash-relay: sin claves de Qobuz para resolver el ISRC")
		}
		ctx, cancel := context.WithTimeout(context.Background(), presupuestoQobuz)
		// La búsqueda se COMPARTE con el canal Qobuz firmado (qobuz_memoria.go):
		// los dos necesitan este id y corren a la vez en la carrera, así que sin
		// esto el mismo ISRC pagaba dos búsquedas idénticas.
		encontrado, err := c.trackIDPorISRCCompartido(ctx, base, trackID)
		cancel()
		if err != nil {
			return "", err
		}
		trackID = encontrado
	}

	cfg, err := c.configStash(false)
	if err != nil {
		return "", err
	}
	enlace, err := c.mintearStash(cfg, trackID, formatID)
	if err == nil {
		// Una línea por resolución: sin esto no se puede distinguir en el log si
		// el FLAC vino de este relay o de otra fuente (todas reportan
		// "flac-rescue" como proveedor).
		log.Printf("[stash-relay] %s -> FLAC del relay en %dms (id=%s)",
			id, time.Since(inicio).Milliseconds(), trackID)
		return enlace, nil
	}
	if esStashNoAutorizado(err) {
		// La clave rotó: se descarta la config cacheada y se reintenta una vez.
		if cfg2, err2 := c.configStash(true); err2 == nil {
			if enlace2, err3 := c.mintearStash(cfg2, trackID, formatID); err3 == nil {
				log.Printf("[stash-relay] %s -> FLAC del relay en %dms (id=%s, tras rotar la clave)",
					id, time.Since(inicio).Milliseconds(), trackID)
				return enlace2, nil
			}
		}
	}
	log.Printf("[stash-relay] %s sin enlace: %v", id, err)
	return "", err
}

// formatoStash mapea la calidad pedida al format_id del relay, o "" cuando el
// relay no sirve ese formato (solo hace sin pérdida).
func formatoStash(formatoPedido string) string {
	if normalizarFormato(formatoPedido) == "FLAC" {
		return stashFormatoFLAC
	}
	return ""
}

// mintearStash hace UNA petición firmada al relay y devuelve la URL validada.
func (c *Client) mintearStash(cfg relayStash, trackID, formatID string) (string, error) {
	install := c.installStash()
	ts := time.Now().Unix()
	firma := firmarStash(cfg.clave, install, trackID, formatID, ts)
	endpoint := cfg.base + "/v1/qobuz/file?" + url.Values{
		"track_id":  {trackID},
		"format_id": {formatID},
	}.Encode()

	ctx, cancel := context.WithTimeout(context.Background(), timeoutStash)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")
	// El relay firma el pedido (spec §5.4): el contrato exacto es
	// X-Stash-Auth = HMAC-SHA256(relay_key, "<install>:<track_id>:<format_id>:<ts>").
	req.Header.Set("X-Stash-Version", "1")
	req.Header.Set("X-Stash-Install", install)
	req.Header.Set("X-Stash-Ts", strconv.FormatInt(ts, 10))
	req.Header.Set("X-Stash-Auth", firma)

	resp, err := c.httpStash(timeoutStash).Do(req)
	if err != nil {
		return "", fmt.Errorf("stash-relay: %v", err)
	}
	defer resp.Body.Close()

	switch {
	case resp.StatusCode == http.StatusOK:
	case resp.StatusCode == http.StatusUnauthorized:
		return "", errStashNoAutorizado("stash-relay: firma rechazada (401)")
	case resp.StatusCode == http.StatusNotFound:
		return "", fmt.Errorf("stash-relay: la pista no está disponible")
	case resp.StatusCode == http.StatusTooManyRequests:
		return "", fmt.Errorf("stash-relay: cupo agotado (429)")
	case resp.StatusCode == http.StatusServiceUnavailable:
		return "", fmt.Errorf("stash-relay: relay ocupado (503)")
	default:
		return "", fmt.Errorf("stash-relay: respuesta %d", resp.StatusCode)
	}

	var payload struct {
		URL        string `json:"url"`
		FormatID   int    `json:"format_id"`
		BitDepth   int    `json:"bit_depth"`
		SampleRate int    `json:"sample_rate"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return "", fmt.Errorf("stash-relay: respuesta no interpretada")
	}
	// Un 200 con error adentro es el peor caso del contrato: se trata como
	// fallo para no devolverle al reproductor una URL que no es.
	if !strings.HasPrefix(payload.URL, "https://") {
		return "", fmt.Errorf("stash-relay: URL no segura")
	}
	if payload.FormatID < 6 {
		return "", fmt.Errorf("stash-relay: el relay devolvió un formato con pérdida")
	}
	// Sin `etsp` el reproductor no puede derivar el vencimiento y rechaza la
	// URL en silencio (spec §1): mejor fallar acá y dejar pasar a los espejos.
	if !etspStash.MatchString(payload.URL) {
		return "", fmt.Errorf("stash-relay: URL sin vencimiento (etsp)")
	}
	return payload.URL, nil
}

// httpStash arma un cliente con el techo que pide el canal y el transporte
// COMPARTIDO del paquete (así el ajuste de proxy lo cubre). Se usa uno propio y
// no el general porque el general está afinado para los espejos (3 s) y la
// config del relay, siendo una petición fría, puede necesitar más.
func (c *Client) httpStash(techo time.Duration) *http.Client {
	return &http.Client{Timeout: techo, Transport: c.http.Transport}
}

// firmarStash reproduce el HMAC del relay. Va aparte para que el test lo
// compruebe contra la implementación de referencia (auth.js del proyecto).
func firmarStash(clave, install, trackID, formatID string, ts int64) string {
	mac := hmac.New(sha256.New, []byte(clave))
	fmt.Fprintf(mac, "%s:%s:%s:%d", install, trackID, formatID, ts)
	return hex.EncodeToString(mac.Sum(nil))
}

// configStash trae (y cachea) la config del relay: la base y la clave con la
// que firmar. [forzar] salta la caché para el reintento tras un 401.
func (c *Client) configStash(forzar bool) (relayStash, error) {
	c.stashConfMu.RLock()
	cfg := c.stashRelayCfg
	configURL := c.stashConfigURL
	c.stashConfMu.RUnlock()

	if !forzar && cfg.base != "" && time.Now().Before(cfg.hasta) {
		return cfg, nil
	}
	if configURL == "" {
		configURL = stashConfigURLPorDefecto
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeoutStashConfig)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, configURL, nil)
	if err != nil {
		return relayStash{}, err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")
	resp, err := c.httpStash(timeoutStashConfig).Do(req)
	if err != nil {
		return relayStash{}, fmt.Errorf("stash-relay: config inalcanzable: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return relayStash{}, fmt.Errorf("stash-relay: la config respondió %d", resp.StatusCode)
	}

	var payload struct {
		V      int `json:"v"`
		Relays []struct {
			Base     string `json:"base"`
			Priority int    `json:"priority"`
		} `json:"relays"`
		RelayKey string `json:"relay_key"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return relayStash{}, fmt.Errorf("stash-relay: config no interpretada")
	}
	// Los relays se prueban por prioridad ascendente (spec §3); acá se toma el
	// primero con una base utilizable. El relay_key es opcional en el contrato
	// (uno sin clave desarma la firma), pero sin él este canal no puede pasar
	// el control de acceso, así que se exige.
	sort.SliceStable(payload.Relays, func(i, j int) bool {
		return payload.Relays[i].Priority < payload.Relays[j].Priority
	})
	base := ""
	for _, r := range payload.Relays {
		if strings.HasPrefix(r.Base, "http") {
			base = strings.TrimRight(r.Base, "/")
			break
		}
	}
	if base == "" || strings.TrimSpace(payload.RelayKey) == "" {
		return relayStash{}, fmt.Errorf("stash-relay: config sin relay utilizable")
	}

	cfg = relayStash{base: base, clave: strings.TrimSpace(payload.RelayKey), hasta: time.Now().Add(ttlStashConfig)}
	c.stashConfMu.Lock()
	c.stashRelayCfg = cfg
	c.stashConfMu.Unlock()
	return cfg, nil
}

// precalentarStashRelay trae la config del relay EN SEGUNDO PLANO, antes de
// que haga falta.
//
// Por qué: el canal paga dos peticiones en serie (config + mint) dentro de un
// presupuesto de ~2 s, y la config se cachea 6 h. Sin precalentarla, la
// PRIMERA canción sin pérdida paga ese GET dentro del camino crítico; medido,
// esa petición en frío costó ~0,8 s (y >4 s un día malo). Al arrancar la app no
// hay nadie esperando, así que es el único momento en que ese costo es gratis.
func (c *Client) precalentarStashRelay() {
	if !c.stashEncendido() {
		return
	}
	go func() {
		if _, err := c.configStash(false); err != nil {
			// Best-effort: si falla, el canal lo reintenta cuando le toque.
			log.Printf("[stash-relay] config no precalentada: %v", err)
		}
	}()
}

// stashEncendido reporta si el canal está habilitado.
func (c *Client) stashEncendido() bool {
	c.stashConfMu.RLock()
	defer c.stashConfMu.RUnlock()
	return c.stashActivo
}

// installStash devuelve el id de instalación (se genera una vez y se recuerda).
// El relay lo usa como cubeta de límite por instalación; es aleatorio y sin
// datos personales, no una identidad.
func (c *Client) installStash() string {
	c.stashConfMu.Lock()
	defer c.stashConfMu.Unlock()
	if c.stashInstall == "" {
		c.stashInstall = installAleatorio()
	}
	return c.stashInstall
}

// installAleatorio arma un id de instalación aleatorio (hex de 16 bytes). El
// relay acepta `^[A-Za-z0-9-]{8,64}$`.
func installAleatorio() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "bitly-" + strconv.FormatInt(time.Now().UnixNano(), 16)
	}
	return hex.EncodeToString(b)
}
