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
const (
	presupuestoTotal = 12 * time.Second
	timeoutPorPedido = 5 * time.Second
	cacheTTL         = 10 * time.Minute
	maxCache         = 256
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
}

type cacheEntry struct {
	url     string
	mirror  string
	expires time.Time
}

// NewClient crea el provider con la configuración por defecto.
func NewClient() *Client {
	return &Client{
		mirrors: append([]string(nil), defaultMirrors...),
		origin:  defaultOrigin,
		formato: "FLAC",
		http:    &http.Client{Timeout: timeoutPorPedido},
		cache:   map[string]cacheEntry{},
	}
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

func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	return nil, errNoCatalogo("búsqueda por nombre")
}

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
	isrc := normalizarISRC(id)
	if isrc == "" {
		return "", errNoCatalogo("se requiere ISRC")
	}
	url, _, err := c.resolverPorISRC(isrc, c.calidadAFormatos(quality))
	return url, err
}
