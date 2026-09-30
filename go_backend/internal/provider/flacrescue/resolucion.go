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

// calidadAFormatos arma la cascada de formatos a intentar: la calidad de
// AJUSTES va primero —es la que el usuario eligió y la que manda— y, si ese
// nivel no está disponible, se cae al resto del mejor al más compatible. Así un
// nivel que la fuente no tiene (o que su pool dejó de servir, como le pasó a los
// espejos de Deezer) no deja la canción sin audio. Antes el nivel PEDIDO por la
// reproducción REEMPLAZABA a la configuración, y con eso una UI pidiendo 320
// sacaba del juego al único canal sin pérdida que el usuario tenía.
//
// La cascada NO depende del nivel pedido, a propósito, por dos motivos:
//   - el pedido ya se respeta POR CANAL (ver `mejor` en resolverPorISRC), que es
//     donde importa: un canal que entrega un formato puntual habla en el nivel
//     pedido;
//   - y hacerla depender del pedido partía la CACHÉ en varias claves por
//     canción. El streaming prueba hasta siete niveles por fuente
//     (high → 3 → 192 → mp3 → 128 → low → flac), así que el mismo ISRC pagaba la
//     carrera de canales varias veces por reproducción (medido: 4,9s en la fase
//     de identificadores y 2,4s en la de nombre, para el mismo ISRC). Con una
//     sola cascada, la segunda consulta la contesta la caché.
func (c *Client) calidadAFormatos() []string {
	base := c.formatoPreferido()
	orden := make([]string, 0, 3)
	orden = append(orden, base)
	for _, formato := range []string{"FLAC", "MP3_320", "MP3_128"} {
		if formato != base {
			orden = append(orden, formato)
		}
	}
	return orden
}

// formatoPreferido es el formato que el usuario configuró en Ajustes. Vacío
// significa FLAC, que es el default de calidadAFormatos: no se distingue "sin
// configurar" de "FLAC" a propósito, porque el comportamiento es el mismo.
func (c *Client) formatoPreferido() string {
	c.mu.RLock()
	f := c.formato
	c.mu.RUnlock()
	if f == "" {
		return "FLAC"
	}
	return f
}

// espejosVivos son los espejos configurados que NO avisaron que su pool quedó
// sin cuentas. Es el mismo filtro que usa la resolución y el que decide, junto
// con el resto de los canales, si el rescate está agotado.
func (c *Client) espejosVivos() []string {
	c.mu.RLock()
	espejos := append([]string(nil), c.mirrors...)
	c.mu.RUnlock()
	vivos := make([]string, 0, len(espejos))
	for _, espejo := range espejos {
		if c.espejoSinCuentas(strings.TrimRight(espejo, "/")) {
			continue
		}
		vivos = append(vivos, espejo)
	}
	return vivos
}

// rescateAgotado reporta si NINGÚN canal de flac-rescue puede entregar audio
// ahora mismo, según el estado que los canales ya publicaron. No hace NI UNA
// petición: mira las pausas por fallo de pool (relay, arcod), las credenciales
// de Qobuz y los espejos marcados sin cuentas.
//
// Por qué existe: los canales ya aprenden que están caídos (pausa del relay,
// backoff de arcod, marca de espejo sin cuentas), pero el rescate seguía
// pagando la carrera entera —y los timeouts de cada canal— antes de aceptarlo.
// Con los cuatro caídos, flac-rescue no puede entregar ni FLAC ni MP3, así que
// esperarlo es tiempo muerto puro.
func (c *Client) rescateAgotado() bool {
	if c.stashEncendido() && !c.relayPausado() {
		return false
	}
	if c.arcodEncendido() && !c.enPausaArcod() {
		return false
	}
	// El canal firmado con las credenciales del usuario abarca el caso bueno: con
	// sesión puede entregar FLAC de primera mano. Pero tener claves NO alcanza:
	// medido en el dispositivo real, con las claves del Worker inyectadas y sin
	// sesión premium, Qobuz solo devolvía una muestra de 30s y el canal se pagaba
	// entero en cada resolución. Si la cuenta ya avisó que no puede servir la
	// canción, no cuenta como canal sano.
	if _, _, _, _, _, ok := c.qobuzCredenciales(); ok && !c.qobuzSinSesion() {
		return false
	}
	return len(c.espejosVivos()) == 0
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
//
// [formatos] es la cascada (ver calidadAFormatos: manda la calidad de Ajustes)
// y [calidadPedida] es el nivel que pidió ESTA reproducción (vacío = ninguno).
// Los canales que entregan un formato puntual se piden en el nivel pedido; la
// cascada la usan los que pueden degradar por sí solos (los espejos).
func (c *Client) resolverPorISRC(isrc string, formatos []string, calidadPedida string) (string, string, error) {
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
	// Cortocircuito de canales AGOTADOS: si ningún canal puede entregar audio
	// con su estado ya conocido, no se corre la carrera. Es gratis (no hace ni
	// una petición) y ahorra lo que se midió en el tap real (ver
	// tap_canciones_nuevas_test.go): con el relay, arcod y los espejos caídos,
	// la carrera en frío tardaba ~4 s —el relay gastaba 2,3 s buscando el id de
	// Qobuz para un mint que iba a contestar 503— y ocupaba un turno de worker
	// en la fase de identificadores, que necesitaban las fuentes que SÍ suenan.
	// El fallo se cachea como cualquier otro (60 s), así que la canción siguiente
	// tampoco lo paga.
	//
	// No cambia nada cuando hay UN canal sano: ahí `rescateAgotado` es false y la
	// carrera corre igual que siempre.
	if c.rescateAgotado() {
		return "", "", c.guardarFallo(claveCache, errors.New("rescate: todos los canales están caídos (relay/espejos/arcod sin cupo y Qobuz sin sesión)"))
	}
	// base es la calidad de AJUSTES (la que ordena la cascada, ver
	// calidadAFormatos).
	base := formatos[0]
	// mejor es el nivel que se le pide a los canales que entregan UN formato
	// puntual (Qobuz firmado, arcod): el que pide ESTA reproducción, y si no
	// pide ninguno, la calidad de Ajustes. Importa que sea el pedido: una URL
	// MP3 directa de Qobuz sin sesión sirve para un pedido con pérdida y NO para
	// uno sin pérdida (ver TestQobuzFirmadoSinTokenNoSeHacePasarPorFLAC).
	mejor := base
	if pedido := normalizarFormato(calidadPedida); pedido != "" {
		mejor = pedido
	}
	// Un resultado es "sin pérdida" si el nivel que se le pidió al canal lo es.
	sinPerdida := mejor == "FLAC"
	// …y la ESPERA por el sin pérdida la fija la calidad de AJUSTES: es la que
	// el usuario eligió, así que un pedido con pérdida con Ajustes en FLAC igual
	// espera la gracia a que llegue el FLAC.
	prefiereSinPerdida := base == "FLAC"
	// Formato con el que se le habla al canal SIN PÉRDIDA (stash-relay): su
	// ÚNICO formato es FLAC. Antes se le pasaba `mejor` tal cual, así que con la
	// calidad de la reproducción en MP3 contestaba "solo sirve sin pérdida" y
	// quedaba afuera —y con él la fase de identificadores entera, que gastaba su
	// presupuesto sin stream—, aunque la calidad de AJUSTES sea FLAC y ese mismo
	// canal SÍ tenga la canción (medido: la búsqueda por nombre, que le pide
	// FLAC, la encontraba 2,4s después). Es el respaldo sin pérdida de la
	// cascada: se le pide siempre su formato, y si el nivel configurado llega
	// antes, gana igual (con la base sin pérdida un resultado con pérdida espera
	// la gracia; ver politicaEspera).
	formatoRelay := "FLAC"

	canales := make([]canalRescate, 0, 4)

	// 1) Qobuz firmado (credenciales propias). Sin credenciales contesta al
	// instante sin hacer NI UNA petición, así que no retiene nada.
	canales = append(canales, canalRescate{
		nombre:     nombreQobuzFirmado,
		grado:      gradoCredenciales,
		sinPerdida: sinPerdida,
		correr: func() (string, bool, error) {
			audioURL, err := c.resolverQobuzFirmado(isrc, mejor)
			// Una muestra de 30s o una degradación por falta de suscriptor NO es
			// un fallo de red: la cuenta no puede servir la canción y va a seguir
			// así tema tras tema (ver qobuz_estado.go). Se marca para que la
			// próxima resolución no vuelva a pagar este canal.
			if errors.Is(err, errQobuzMuestraCorta) || errors.Is(err, errQobuzSinSesion) {
				c.marcarQobuzSinSesion()
			}
			return audioURL, !sinPerdida, err
		},
	})

	// 2) stash-relay: relay público que mintea la URL del CDN de Qobuz. Solo
	// sirve sin pérdida, así que se le pide SU formato (ver formatoRelay).
	canales = append(canales, canalRescate{
		nombre:     nombreStashRelay,
		grado:      gradoSinPerdida,
		sinPerdida: true,
		correr: func() (string, bool, error) {
			enlace, err := c.resolverStashRelay(isrc, formatoRelay)
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
	vivos := c.espejosVivos()

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
	if prefiereSinPerdida {
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
