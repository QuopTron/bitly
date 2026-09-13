// client.go — Proveedor de Internet Archive (archive.org): catálogo de audio
// libre de FLAC real, SIN API key, SIN cuenta y SIN gateway intermedio.
//
// Por qué existe: el resto de las fuentes lossless (Deezer/Tidal/Qobuz/Amazon)
// dependen de cuentas o de un gateway firmado; cuando no hay sesión, la
// reproducción cae a un re-subido lossy. Internet Archive publica FLAC de
// verdad con una API abierta y estable (advancedsearch + metadata), así que es
// la única ruta que garantiza lossless sin pedirle nada al usuario.
//
// Contrato usado (verificado contra el servicio real):
//
//	GET /advancedsearch.php?q=...&fl[]=identifier&...&output=json  → items
//	GET /metadata/<identifier>                                     → files[]
//	GET /download/<identifier>/<name>                              → audio
//
// Qué NO tiene: ISRC (los items no lo publican), así que en el rescate solo
// puede identificarse por nombre — igual que YouTube/SoundCloud.
//
// Se conecta con: gobackend/exports_init_providers.go (registro),
// streaming/play_types.go (orden de streaming) y download (orden de descarga).
// Parte del flujo: fuente de audio lossless sin sesión.
package internetarchive

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cache"
	"github.com/zarz/bitly/go_backend/internal/httpclient"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// name es el id con el que la fuente aparece en la UI y en el registry.
const name = "internetarchive"

// baseURL es el host público de archive.org (no requiere clave).
const baseURL = "https://archive.org"

// prefijoID separa el id de proveedor del id real, como hace soundcloud con
// "sc:". El formato es "ia:<identificador>/<archivo>".
const prefijoID = "ia:"

// Tiempos de caché. La metadata de un item es inmutable en la práctica (una
// subida no cambia de archivos) y la búsqueda se repite al teclear, así que se
// cachean con TTLs distintos.
const (
	ttlCacheBusqueda = 2 * time.Minute
	ttlCacheItem     = 10 * time.Minute
	ttlCachePista    = 10 * time.Minute

	marcaUserAgent = "bitly/1.0 (+https://archive.org)"
)

// Client implementa provider.Provider leyendo la API abierta de archive.org.
type Client struct {
	http *http.Client
	base string

	busquedas      *cache.Cache[[]provider.TrackResult]
	busquedasItems *cache.Cache[[]itemResumen]
	items          *cache.Cache[*Item]
	pistas         *cache.Cache[*provider.TrackResult]
}

// NewClient crea el proveedor. [httpClient] nil usa el cliente HTTP del
// proyecto (reintentos, breaker por host y timeouts compartidos).
func NewClient(httpClient *http.Client) *Client {
	if httpClient == nil {
		cfg := httpclient.DefaultConfig()
		cfg.Timeout = 20 * time.Second
		httpClient = httpclient.NewClient(cfg)
	}
	return &Client{
		http:           httpClient,
		base:           baseURL,
		busquedas:      cache.New[[]provider.TrackResult](ttlCacheBusqueda, 5*time.Minute),
		busquedasItems: cache.New[[]itemResumen](ttlCacheBusqueda, 5*time.Minute),
		items:          cache.New[*Item](ttlCacheItem, 5*time.Minute),
		pistas:         cache.New[*provider.TrackResult](ttlCachePista, 5*time.Minute),
	}
}

// Name implementa provider.Provider.
func (c *Client) Name() string { return name }

// SetBaseURL reescribe el host base (tests y espejos internos).
func (c *Client) SetBaseURL(base string) {
	base = strings.TrimRight(strings.TrimSpace(base), "/")
	if base != "" {
		c.base = base
	}
}

// doJSON pide una URL de archive.org y decodifica la respuesta en [out].
func (c *Client) doJSON(endpoint string, out any) error {
	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", marcaUserAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("%s: HTTP %d en %s", name, resp.StatusCode, endpoint)
	}
	if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
		return fmt.Errorf("%s: respuesta ilegible: %w", name, err)
	}
	return nil
}

// listaUnica devuelve [valor] si no está vacío, o el primer elemento no vacío de
// [alternativas]. La API de archive.org devuelve algunos campos como string y
// otros como array según el item, así que hay que tolerar ambos.
func primerNoVacio(valor string, alternativas ...string) string {
	if v := strings.TrimSpace(valor); v != "" {
		return v
	}
	for _, a := range alternativas {
		if v := strings.TrimSpace(a); v != "" {
			return v
		}
	}
	return ""
}

// urlItem arma la URL del thumbnail público de un item (sin clave).
func (c *Client) urlItem(identifier string) string {
	if strings.TrimSpace(identifier) == "" {
		return ""
	}
	return c.base + "/services/img/" + url.PathEscape(identifier)
}

// urlDescarga arma la URL de descarga de un archivo del item, escapando cada
// segmento (los nombres pueden traer espacios, acentos, # y +).
func (c *Client) urlDescarga(identifier, archivo string) string {
	segmentos := strings.Split(strings.TrimPrefix(archivo, "/"), "/")
	for i, s := range segmentos {
		segmentos[i] = url.PathEscape(s)
	}
	return c.base + "/download/" + url.PathEscape(identifier) + "/" + strings.Join(segmentos, "/")
}

// limiteValido acota el límite pedido a un rango razonable.
func limiteValido(limit int) int {
	if limit < 1 {
		return 25
	}
	if limit > 100 {
		return 100
	}
	return limit
}

// atoiSeguro convierte sin fallar (campos numéricos de la API pueden ser basura).
func atoiSeguro(v string) int {
	n, err := strconv.Atoi(strings.TrimSpace(v))
	if err != nil {
		return 0
	}
	return n
}
