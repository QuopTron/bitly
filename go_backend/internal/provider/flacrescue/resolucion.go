// ─────────────────────────────────────────────────────────────
// resolucion.go — Resolución de un ISRC a URL de audio: la CARRERA
// de canales (Qobuz firmado, stash-relay, arcod y los espejos por
// formato), con caché, presupuestos por canal y errores legibles.
//
// El orden de intentos ya no es una lista serial: los canales corren
// a la vez y la preferencia se aplica reteniendo un resultado, no
// esperándolo antes de empezar (ver resolucion_carrera.go, que
// explica por qué y qué se conserva).
//
// Se conecta con: client.go (configuración) y el orquestador de
// descarga/streaming, que llama a GetStreamURL.
// Parte del flujo: interior del rescate de audio (no se usa solo).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// nombreQobuzFirmado es cómo se reporta el canal de credenciales propias
// (también es la clave con la que queda en la caché).
const nombreQobuzFirmado = "qobuz-firmado"

// nombreEspejos es cómo se reporta el canal de los espejos por ISRC.
const nombreEspejos = "espejos"

// errNoCatalogo es el error de los métodos que flac-rescue no soporta.
func errNoCatalogo(qué string) error {
	return fmt.Errorf("flac-rescue: %s no soportada (solo resuelve audio por ISRC)", qué)
}

// normalizarISRC limpia y valida el ISRC. Acepta el prefijo
// "<proveedor>:" que a veces traen los ids del feed.
func normalizarISRC(id string) string {
	if i := strings.LastIndex(id, ":"); i >= 0 {
		id = id[i+1:]
	}
	id = strings.ToUpper(strings.TrimSpace(id))
	if len(id) < 5 {
		return ""
	}
	return id
}

// normalizarFormato mapea la calidad pedida a un formato del contrato.
func normalizarFormato(v string) string {
	switch strings.ToUpper(strings.TrimSpace(v)) {
	case "FLAC", "LOSSLESS", "HI_RES", "HIRES", "24", "16":
		return "FLAC"
	case "MP3_320", "320", "HIGH":
		return "MP3_320"
	case "MP3_128", "128", "LOW":
		return "MP3_128"
	default:
		return ""
	}
}

// parseMirrors acepta "https://a,https://b" (o saltos de línea) y
// también un array JSON ["https://a","https://b"].
func parseMirrors(raw string) []string {
	raw = strings.TrimSpace(raw)
	var lista []string
	if strings.HasPrefix(raw, "[") {
		_ = json.Unmarshal([]byte(raw), &lista)
	} else {
		lista = strings.FieldsFunc(raw, func(r rune) bool {
			return r == ',' || r == '\n' || r == '\r' || r == ' '
		})
	}
	limpios := make([]string, 0, len(lista))
	vistos := map[string]bool{}
	for _, m := range lista {
		m = strings.TrimRight(strings.TrimSpace(m), "/")
		if len(m) < 9 || !strings.HasPrefix(m, "http") || vistos[m] {
			continue
		}
		vistos[m] = true
		limpios = append(limpios, m)
	}
	return limpios
}

// calidadAFormatos arma la cascada de formatos a intentar, del mejor
// al más compatible. Así una fuente que ya no tiene FLAC (como le pasó
// a los espejos de Deezer) igual entrega MP3 en vez de fallar.
func (c *Client) calidadAFormatos(quality string) []string {
	c.mu.RLock()
	preferido := c.formato
	c.mu.RUnlock()

	if pedido := normalizarFormato(quality); pedido != "" {
		preferido = pedido
	}
	switch preferido {
	case "MP3_128":
		return []string{"MP3_128"}
	case "MP3_320":
		return []string{"MP3_320", "MP3_128"}
	default: // FLAC
		return []string{"FLAC", "MP3_320", "MP3_128"}
	}
}

// ttlDeCanal es lo que se recuerda la URL que entregó [canal]. Los enlaces
// firmados de terceros caducan, así que su TTL es más corto que el de una URL de
// CDN de primera mano.
func ttlDeCanal(canal string) time.Duration {
	switch canal {
	case nombreArcod:
		return ttlArcods
	case nombreStashRelay:
		return ttlStashEnlace
	default:
		return cacheTTL
	}
}

// resolverPorISRC corre TODOS los canales a la vez y devuelve el primero que
// entregue audio, reteniendo un resultado de menor preferencia una gracia corta
// a que llegue uno mejor. Cachea el resultado positivo y respeta el presupuesto
// de cada canal.
func (c *Client) resolverPorISRC(isrc string, formatos []string) (string, string, error) {
	c.mu.RLock()
	espejos := append([]string(nil), c.mirrors...)
	c.mu.RUnlock()

	claveCache := isrc + "@" + strings.Join(formatos, ",")
	c.cacheMu.Lock()
	if e, ok := c.cache[claveCache]; ok && time.Now().Before(e.expires) {
		c.cacheMu.Unlock()
		if e.url == "" {
			return "", "", fmt.Errorf("flac-rescue: %s", e.falla)
		}
		return e.url, e.mirror, nil
	}
	c.cacheMu.Unlock()

	if len(formatos) == 0 {
		return "", "", c.guardarFallo(claveCache, errors.New("sin formato que pedir"))
	}
	mejor := formatos[0]
	// Lo que el pedido espera: con calidad sin pérdida, un resultado degradado
	// (solo los espejos pueden entregarlo) espera a que llegue el FLAC.
	sinPerdida := mejor == "FLAC"

	canales := make([]canalRescate, 0, 4)

	// 1) Qobuz firmado (credenciales propias). Sin credenciales contesta al
	// instante sin hacer NI UNA petición, así que no retiene nada.
	canales = append(canales, canalRescate{
		nombre:     nombreQobuzFirmado,
		grado:      gradoCredenciales,
		sinPerdida: sinPerdida,
		correr: func() (string, bool, error) {
			audioURL, err := c.resolverQobuzFirmado(isrc, mejor)
			return audioURL, !sinPerdida, err
		},
	})

	// 2) stash-relay: relay público que mintea la URL del CDN de Qobuz. Solo
	// sirve sin pérdida (un pedido con pérdida se rechaza solo).
	canales = append(canales, canalRescate{
		nombre:     nombreStashRelay,
		grado:      gradoSinPerdida,
		sinPerdida: true,
		correr: func() (string, bool, error) {
			enlace, err := c.resolverStashRelay(isrc, mejor)
			return enlace, false, err
		},
	})

	// 3) arcod: el FLAC real del catálogo de Qobuz, sin cuenta y con rangos (así
	// que sirve para reproducir Y para descargar).
	canales = append(canales, canalRescate{
		nombre:     nombreArcod,
		grado:      gradoSinPerdida,
		sinPerdida: sinPerdida,
		correr: func() (string, bool, error) {
			enlace, err := c.resolverArcod(isrc, mejor)
			return enlace, !sinPerdida, err
		},
	})

	// Los espejos que ya avisaron que no tienen cuentas vivas se saltan: probarlos
	// cuesta un timeout entero por formato para un error que no va a cambiar en
	// los próximos minutos.
	vivos := make([]string, 0, len(espejos))
	for _, espejo := range espejos {
		if c.espejoSinCuentas(strings.TrimRight(espejo, "/")) {
			continue
		}
		vivos = append(vivos, espejo)
	}

	// Con todos los espejos marcados, el canal no existe y guardamos su motivo
	// para poder decirlo si no hay nada más.
	var errorEspejos error
	if len(espejos) > 0 && len(vivos) == 0 {
		errorEspejos = errors.New("todos los espejos están sin cuentas vivas")
	} else if len(espejos) == 0 {
		errorEspejos = errors.New("sin espejos configurados")
	}

	// 4) Espejos por ISRC. La cascada de FORMATOS sigue siendo serial (primero
	// FLAC, después MP3): lo que va en paralelo son los espejos DENTRO de cada
	// formato, así que el tiempo es el del más rápido en vez de la suma.
	if len(vivos) > 0 {
		canales = append(canales, canalRescate{
			nombre:     nombreEspejos,
			grado:      gradoEspejos,
			sinPerdida: true,
			correr: func() (string, bool, error) {
				fin := time.Now().Add(presupuestoTotal)
				var ultimo error
				for _, formato := range formatos {
					if time.Now().After(fin) {
						break
					}
					audioURL, _, err := c.carreraPorFormato(vivos, isrc, formato, fin)
					if err != nil {
						ultimo = err
						continue
					}
					return audioURL, formato != "FLAC", nil
				}
				if ultimo == nil {
					ultimo = errors.New("sin respuesta de los espejos")
				}
				return "", false, ultimo
			},
		})
	}

	// Con pérdida pedida no se espera a nadie (el primero que llegue sirve);
	// con calidad sin pérdida se retiene para no entregar un MP3 que estaba a
	// un segundo de ser FLAC.
	politica := politicaEspera{}
	if sinPerdida {
		politica = politicaEspera{
			conPerdida:     graciaRescateLossless,
			porPreferencia: graciaRescatePreferencia,
		}
	}
	audioURL, fuente, err := carreraDeCanales(canales, politica)
	// Segunda defensa (la primera está en la carrera): una URL vacía NUNCA es un
	// stream. Si algo contestara "sin error" y sin enlace, esto evita cachear un
	// vacío que el reproductor recibiría como éxito y mostraría como silencio.
	if err == nil && strings.TrimSpace(audioURL) == "" {
		err = errors.New("rescate: la carrera no devolvió enlace de audio")
	}
	if err != nil {
		// Si no hubo ni un canal que pudiera entregar algo, el motivo útil es
		// el de los espejos (es el que el usuario configuró).
		if errors.Is(err, errNingunCanalDioAudio) && errorEspejos != nil {
			err = errorEspejos
		}
		return "", "", c.guardarFallo(claveCache, err)
	}
	c.guardarCacheTTL(claveCache, audioURL, fuente, ttlDeCanal(fuente))
	return audioURL, fuente, nil
}

// guardarFallo memoriza un fallo por [ttlFallo] y devuelve el error ya
// envuelto, para que el llamador solo tenga que retornarlo.
func (c *Client) guardarFallo(clave string, causa error) error {
	c.cacheMu.Lock()
	if len(c.cache) > maxCache {
		c.cache = map[string]cacheEntry{}
	}
	c.cache[clave] = cacheEntry{falla: causa.Error(), expires: time.Now().Add(ttlFallo)}
	c.cacheMu.Unlock()
	return fmt.Errorf("flac-rescue: %v", causa)
}

// guardarCacheTTL memoriza un acierto con la vida que le corresponde al canal
// (y acota el tamaño de la caché). Tiene TTL propio porque los enlaces firmados
// de arcod caducan: su vida es más corta que la de una URL de CDN.
func (c *Client) guardarCacheTTL(clave, url, espejo string, ttl time.Duration) {
	c.cacheMu.Lock()
	defer c.cacheMu.Unlock()
	if len(c.cache) > maxCache {
		c.cache = map[string]cacheEntry{}
	}
	c.cache[clave] = cacheEntry{url: url, mirror: espejo, expires: time.Now().Add(ttl)}
}

// endpointsDeEspejo arma las URLs a probar para un ISRC y formato, del contrato
// MÁS NUEVO al más viejo:
//
//	/track/?isrc=X&quality=FLAC   ← contrato actual del espejo (lo que su propio
//	                                endpoint /search/ documenta como usage)
//	/stream/?isrc=X&format=FLAC   ← contrato viejo (audio binario directo)
//
// Se mantienen los dos porque no todos los espejos migraron al mismo tiempo, y
// el espejo que responde con uno no necesariamente responde con el otro.
func endpointsDeEspejo(base, isrc, formato string) []string {
	e := url.QueryEscape(isrc)
	return []string{
		base + "/track/?isrc=" + e + "&quality=" + url.QueryEscape(formato),
		base + "/stream/?isrc=" + e + "&format=" + url.QueryEscape(formato),
	}
}

// resolverEnEspejo pregunta a UN espejo por el ISRC con un formato, probando los
// contratos conocidos. Acepta dos respuestas: audio binario directo (lo ideal, se
// devuelve la propia URL) o JSON con la URL del audio.
func (c *Client) resolverEnEspejo(espejo, isrc, formato string) (string, error) {
	base := strings.TrimRight(espejo, "/")
	var ultimo error
	for _, endpoint := range endpointsDeEspejo(base, isrc, formato) {
		audioURL, err := c.pedirAudio(endpoint, base)
		if err == nil {
			return audioURL, nil
		}
		ultimo = err
		// Un espejo sin cuentas vivas no va a responder distinto por el otro
		// contrato: se marca para no volver a pagarlo en la misma resolución.
		if esFalloDePool(err) {
			c.marcarEspejoSinCuentas(base)
			break
		}
	}
	if ultimo == nil {
		ultimo = errors.New("sin endpoints que probar")
	}
	return "", ultimo
}

// pedirAudio hace UNA petición y traduce la respuesta a una URL reproducible.
func (c *Client) pedirAudio(endpoint, base string) (string, error) {
	c.mu.RLock()
	origin := c.origin
	c.mu.RUnlock()

	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return "", err
	}
	// Origin/Referer: los espejos de esta familia responden 403
	// "requests must come from an allowed site" sin estas cabeceras.
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "*/*")
	req.Header.Set("Origin", origin)
	req.Header.Set("Referer", origin+"/")

	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("%s: %v", base, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return "", fmt.Errorf("%s (%d): %s", base, resp.StatusCode, mensajeEspejo(resp))
	}
	// Caso 1: el espejo sirve el audio directo.
	if ct := resp.Header.Get("Content-Type"); strings.HasPrefix(ct, "audio/") {
		return endpoint, nil
	}
	// Caso 2: JSON con la URL del audio.
	var payload map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return "", fmt.Errorf("%s: respuesta no interpretada", base)
	}
	if u := buscarURL(payload); u != "" {
		return u, nil
	}
	return "", fmt.Errorf("%s: sin URL de audio en la respuesta", base)
}

// esFalloDePool reconoce el error con el que un espejo avisa que su pool de
// cuentas quedó sin credenciales vivas — el estado real de los espejos públicos
// en 2026. Distinguirlo permite saltar el espejo (y no gastar el presupuesto en
// cada formato) hasta que su pool se recupere.
func esFalloDePool(err error) bool {
	if err == nil {
		return false
	}
	e := strings.ToLower(err.Error())
	for _, marca := range []string{
		"accounts are dead", "no accounts", "sin cuentas", "no disponible",
		"all accounts", "accounts exhausted", "pool",
	} {
		if strings.Contains(e, marca) {
			return true
		}
	}
	return false
}

// mensajeEspejo extrae el "error" del JSON del espejo para poder decirle
// al usuario POR QUÉ falló (p.ej. "All Deezer accounts are dead").
func mensajeEspejo(resp *http.Response) string {
	var payload struct {
		Error string `json:"error"`
		Det   string `json:"detail"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return "sin detalle"
	}
	if payload.Error != "" {
		return payload.Error
	}
	if payload.Det != "" {
		return payload.Det
	}
	return "sin detalle"
}

// buscarURL busca la URL de audio en las claves que usan los espejos.
func buscarURL(payload map[string]any) string {
	for _, k := range []string{"url", "audioUrl", "streamUrl", "OriginalTrackUrl", "directURL", "link"} {
		if v, ok := payload[k].(string); ok && strings.HasPrefix(v, "http") {
			return v
		}
	}
	if data, ok := payload["data"].(map[string]any); ok {
		return buscarURL(data)
	}
	return ""
}
