// ─────────────────────────────────────────────────────────────
// client.go — Provider de rescate de audio por ISRC (flac-rescue).
//
// Qué hace: convierte un ISRC en la URL de audio directa consultando
// una lista de "espejos" (mirrors) públicos que exponen el contrato
// monochrome:  GET {base}/stream/?isrc=X&format=FLAC
//
// Por qué existe: las rutas de descarga de deezer/tidal/amazon sin
// cuenta propia dependían del gateway zarz (caído o con verificación
// de humano). Este provider es el reemplazo: sin cuentas, sin
// turnstile, solo ISRC + espejos intercambiables en caliente.
//
// La lección de monochrome.tf: los espejos viven en CONFIGURACIÓN, no
// en código. Si uno cae (como pasó con DAB y squid.wtf), el usuario
// pega otra URL en Ajustes → Credenciales y todo sigue funcionando
// SIN actualizar la app.
//
// Se conecta con: exports_init_providers.go (registro),
// streaming/play_types.go (fullStreamProviders → rescate de
// reproducción), download/orchestrator_fallback.go (orden de descarga)
// y extensions_settings.go (SetSettings vía setExtensionSettings).
// Parte del flujo: descarga y streaming (último recurso exacto por ISRC).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// defaultMirrors son los espejos conocidos. Todos exigen que la
// petición llegue con un Origin/Referer "de sitio permitido", por eso
// defaultOrigin existe: sin esa cabecera el espejo responde 403.
var defaultMirrors = []string{
	"https://dzr.tabs-vs-spaces.wtf",
}

// defaultOrigin es el único Origin que los espejos de la familia
// monochrome aceptan. Configurable por si mueven la web.
const defaultOrigin = "https://monochrome.tf"

// userAgent realista: los espejos rechazan clientes desconocidos.
const userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
	"AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

// presupuestoTotal limita lo que un ISRC puede tardar entre todos los
// espejos y formatos: el rescate no puede bloquear la reproducción.
//
// Se bajó de 12s a 5s al pasar a la PRIMERA fase del rescate (antes iba último y
// su lentitud casi nunca importaba): con un espejo caído, el presupuesto largo
// retenía un slot de la carrera exacta y retrasaba la reproducción de todas las
// demás fuentes.
const (
	presupuestoTotal = 5 * time.Second
	timeoutPorPedido = 3 * time.Second
	cacheTTL         = 10 * time.Minute
	// ttlFallo recuerda un fallo (espejo caído / sin cuentas) para no volver a
	// pagar el timeout completo en cada reproducción mientras siga caído.
	ttlFallo = 60 * time.Second
	maxCache = 256
)

// Client implementa provider.Provider. La metadata NO es suya: solo
// resuelve audio por ISRC (GetTrackByISRC incluido) para que el
// orquestador pueda confirmar el match.
type Client struct {
	mu      sync.RWMutex
	mirrors []string
	origin  string
	formato string // formato preferido: FLAC | MP3_320 | MP3_128
	http    *http.Client

	cacheMu sync.Mutex
	cache   map[string]cacheEntry

	// sinCuentas recuerda los espejos que avisaron que su pool de credenciales
	// quedó sin cuentas vivas. Sin esto, cada canción volvía a pedirles y pagaba
	// su timeout completo antes de pasar al siguiente.
	sinCuentasMu sync.Mutex
	sinCuentas   map[string]time.Time

	// Canal "Qobuz firmado" (ver qobuz_firmado.go): credenciales con las que se
	// firma la petición a la API de Qobuz. Vacías = canal apagado (estado por
	// defecto: sin ellas no se paga ni una petición).
	qobuzBase    string
	qobuzAppID   string
	qobuzSecreto string
	qobuzToken   string
	qobuzFormato string
	// qobuzKeysURL es el origen opcional de claves (ver qobuz_claves.go): si
	// está configurado, las claves se piden y se refrescan solas.
	qobuzKeysURL string

	clavesMu sync.Mutex
	claves   clavesQobuz
}

type cacheEntry struct {
	url    string
	mirror string
	// falla trae el motivo del último fallo cuando no hubo audio (url vacío).
	// Evita repetir la cascada completa (espejos × formatos, con sus timeouts)
	// en cada reproducción mientras el espejo siga respondiendo mal.
	falla   string
	expires time.Time
}

// NewClient crea el provider con la configuración por defecto.
func NewClient() *Client {
	return &Client{
		mirrors:    append([]string(nil), defaultMirrors...),
		origin:     defaultOrigin,
		formato:    "FLAC",
		http:       &http.Client{Timeout: timeoutPorPedido},
		cache:      map[string]cacheEntry{},
		sinCuentas: map[string]time.Time{},
	}
}

// ttlEspejoSinCuentas es cuánto se recuerda que un espejo se quedó sin cuentas.
// Cinco minutos: si el maintainer recarga su pool, la app lo retoma solo.
const ttlEspejoSinCuentas = 5 * time.Minute

// marcarEspejoSinCuentas anota que [base] respondió que no tiene credenciales
// vivas, para saltarlo sin pagar su timeout en las próximas reproducciones.
func (c *Client) marcarEspejoSinCuentas(base string) {
	if base == "" {
		return
	}
	c.sinCuentasMu.Lock()
	defer c.sinCuentasMu.Unlock()
	if len(c.sinCuentas) > 64 {
		c.sinCuentas = map[string]time.Time{}
	}
	c.sinCuentas[base] = time.Now()
}

// espejoSinCuentas reporta si [base] se marcó como sin cuentas hace poco.
func (c *Client) espejoSinCuentas(base string) bool {
	c.sinCuentasMu.Lock()
	defer c.sinCuentasMu.Unlock()
	at, ok := c.sinCuentas[base]
	if !ok {
		return false
	}
	if time.Since(at) > ttlEspejoSinCuentas {
		delete(c.sinCuentas, base)
		return false
	}
	return true
}

// Name implementa provider.Provider.
func (c *Client) Name() string { return "flac-rescue" }

// SetSettings aplica la configuración que llega de Flutter
// (setExtensionSettings con extension_id "flac-rescue"):
//
//	mirrors → "https://a,https://b" o JSON ["https://a","https://b"]
//	origin  → cabecera Origin/Referer (por defecto la de monochrome)
//	format  → FLAC | MP3_320 | MP3_128 (formato preferido)
//
// Es best-effort: un valor inválido se ignora y se conserva el actual,
// para que un ajuste mal pegado no rompa el rescate.
func (c *Client) SetSettings(settings map[string]string) {
	if len(settings) == 0 {
		return
	}
	c.aplicarAjustesEspejos(settings)
	c.SetSettingsQobuz(settings)
}

// aplicarAjustesEspejos aplica el bloque de espejos (mirrors/origin/format),
// que es independiente del canal Qobuz firmado.
func (c *Client) aplicarAjustesEspejos(settings map[string]string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if v := strings.TrimSpace(settings["mirrors"]); v != "" {
		if espejos := parseMirrors(v); len(espejos) > 0 {
			c.mirrors = espejos
			c.cacheMu.Lock()
			c.cache = map[string]cacheEntry{} // espejos nuevos, caché vieja fuera
			c.cacheMu.Unlock()
		}
	}
	if v := strings.TrimSpace(settings["origin"]); strings.HasPrefix(v, "http") {
		c.origin = strings.TrimRight(v, "/")
	}
	if v := normalizarFormato(settings["format"]); v != "" {
		c.formato = v
	}
}

// SetSettingsQobuz aplica los ajustes del canal Qobuz firmado. Va aparte
// para que SetSettings no crezca con un tema que no tiene nada que ver con
// los espejos (y para que un test pueda fijar el canal sin tocar espejos).
func (c *Client) SetSettingsQobuz(settings map[string]string) {
	if !tocaQobuz(settings) {
		return
	}
	if !c.aplicarAjustesQobuz(settings) {
		return
	}
	c.cacheMu.Lock()
	c.cache = map[string]cacheEntry{} // credenciales nuevas, resoluciones viejas fuera
	c.cacheMu.Unlock()
}

// Mirrors devuelve una copia de la lista actual (estado/debug).
func (c *Client) Mirrors() []string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return append([]string(nil), c.mirrors...)
}

// ─────────────────────────────────────────────────────────────
// provider.Provider — flac-rescue resuelve AUDIO, no catálogo. Los
// métodos de búsqueda devuelven error porque no tiene metadata propia.
// ─────────────────────────────────────────────────────────────

func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	return nil, errNoCatalogo("búsqueda de álbumes")
}

func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	return nil, errNoCatalogo("búsqueda de artistas")
}

func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	return nil, errNoCatalogo("búsqueda de playlists")
}

func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	return nil, errNoCatalogo("álbumes")
}

func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	return nil, errNoCatalogo("artistas")
}

// GetTrack trata el id como ISRC (no hay catálogo propio).
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	return c.GetTrackByISRC(id)
}

// GetTrackByISRC es el punto de entrada de metadata mínima: el match lo
// confirma el orquestador con el título/artista que él ya tenía.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	normalizado := normalizarISRC(isrc)
	if normalizado == "" {
		return nil, errNoCatalogo("ISRC vacío")
	}
	return &provider.TrackResult{
		ID:       normalizado,
		Title:    normalizado,
		ISRC:     normalizado,
		Provider: "flac-rescue",
	}, nil
}

// GetStreamURL resuelve un ISRC a URL de audio directa. Es el método
// crítico: el orquestador lo llama en streaming y descarga.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	clave := normalizarISRC(id)
	// Un id de PISTA (numérico, del catálogo de Qobuz) no es un ISRC y puede
	// tener menos de 5 caracteres: se acepta tal cual para que el canal Qobuz
	// firmado resuelva en UNA petición cuando el llamador ya tiene el id.
	if clave == "" && esIDNumerico(strings.TrimSpace(id)) {
		clave = strings.TrimSpace(id)
	}
	if clave == "" {
		return "", errNoCatalogo("se requiere ISRC")
	}
	url, _, err := c.resolverPorISRC(clave, c.calidadAFormatos(quality))
	return url, err
}
