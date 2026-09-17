// ─────────────────────────────────────────────────────────────
// client.go — Canal "Tidal HiFi" anónimo: un catálogo Tidal con ISRC y el
// audio sin pérdida REAL (FLAC 44,1 kHz) sin cuenta y sin captcha.
//
// De dónde sale: el descargador tidal-dl.pages.dev usa su propia API sobre
// Cloudflare Workers (hifi-api, open source) y publica un health-check con
// la lista de proxies ACTIVOS. Este cliente habla ese contrato:
//
//	GET /track?id=<id>                          → metadata (incluye isrc y duración)
//	GET /tracks?q=<texto>                       → búsqueda
//	GET /manifests?id=<id>&quality=LOSSLESS     → URL del manifiesto DASH
//
// Por qué importa el ISRC: el catálogo lo expone, así que la identidad de
// una canción se confirma con ISRC + duración, no con parecido de nombres.
//
// Se conecta con: catalogo.go, manifiesto.go, descarga.go y salud.go.
// Parte del flujo: descarga (rescate de FLAC exacto).
// ─────────────────────────────────────────────────────────────

package tidalhifi

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// basesDeFabrica son las APIs del propio sitio, en orden de intento.
var basesDeFabrica = []string{
	"https://hifi.rhythmax.workers.dev",
	"https://hifi.rtmx.workers.dev",
}

const (
	// timeoutPedido es el techo de cada petición de METADATA/manifiesto. Los
	// segmentos de audio usan su propio cliente, sin este techo corto.
	timeoutPedido = 12 * time.Second
	// userAgent realista: las APIs sobre Cloudflare rechazan clientes raros.
	userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
		"(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)

// Client implementa provider.Provider y sabe bajar el FLAC (ver descarga.go).
type Client struct {
	http *http.Client

	mu         sync.RWMutex
	bases      []string
	saludLeida time.Time
	salud      []string
}

// NewClient arma el cliente con las bases de fábrica.
func NewClient() *Client {
	return &Client{
		http:  &http.Client{Timeout: timeoutPedido},
		bases: append([]string(nil), basesDeFabrica...),
	}
}

// Name implementa provider.Provider.
func (c *Client) Name() string { return "tidal-hifi" }

// listaDeBases devuelve las bases a intentar: primero las de fábrica y después
// los proxies del health-check (los que estaban vivos la última vez que se
// consultó). Se deduplica para no pegarle dos veces al mismo host.
func (c *Client) listaDeBases() []string {
	c.mu.RLock()
	bases := append([]string(nil), c.bases...)
	proxies := append([]string(nil), c.salud...)
	c.mu.RUnlock()

	vistas := map[string]bool{}
	salida := make([]string, 0, len(bases)+len(proxies))
	for _, b := range append(bases, proxies...) {
		b = strings.TrimRight(strings.TrimSpace(b), "/")
		if b == "" || vistas[b] {
			continue
		}
		vistas[b] = true
		salida = append(salida, b)
	}
	return salida
}

// pedir hace un GET contra la primera base que responda y deserializa el JSON.
//
// Si TODAS las bases fallan, relee la lista de proxies vivos y reintenta una
// sola vez: así un proxy caído se reemplaza solo, sin actualizar la app ni
// reiniciarla (mismo criterio que los espejos configurables de flac-rescue).
func (c *Client) pedir(ruta string, destino any) error {
	ultimo := fmt.Errorf("tidal-hifi: sin bases configuradas")
	for intento := 0; intento < 2; intento++ {
		for _, base := range c.listaDeBases() {
			cuerpo, err := c.pedirCrudo(base + ruta)
			if err != nil {
				ultimo = err
				continue
			}
			if err := json.Unmarshal(cuerpo, destino); err != nil {
				ultimo = fmt.Errorf("%s: respuesta ilegible", base)
				continue
			}
			return nil
		}
		if intento == 0 && c.refrescarSalud() == 0 {
			break
		}
	}
	return ultimo
}

// pedirCrudo trae el cuerpo de una URL completa.
func (c *Client) pedirCrudo(url string) ([]byte, error) {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", url, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("%s: HTTP %d", url, resp.StatusCode)
	}
	return io.ReadAll(io.LimitReader(resp.Body, 8<<20))
}

// noCatalogo es el error de los métodos que este canal no cubre.
func noCatalogo(que string) error {
	return fmt.Errorf("tidal-hifi: %s no soportada (solo audio sin pérdida)", que)
}

func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	return nil, noCatalogo("búsqueda de álbumes")
}

func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	return nil, noCatalogo("búsqueda de artistas")
}

func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	return nil, noCatalogo("búsqueda de playlists")
}

func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	return nil, noCatalogo("álbumes")
}

func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	return nil, noCatalogo("artistas")
}

// GetStreamURL no entrega una URL reproducible: el audio de Tidal llega en
// segmentos DASH que hay que unir (ver descarga.go). Se avisa con un error
// claro en vez de devolver algo que el reproductor no puede abrir.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	return "", fmt.Errorf("tidal-hifi: el audio llega en segmentos, se baja con el descargador")
}
