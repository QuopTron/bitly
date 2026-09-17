// Package lastfm lee la ficha pública de un tema en Last.fm (HTML, sin cuenta
// ni API key) para dos cosas que ninguna otra fuente da juntas: el nombre
// CANÓNICO del tema y el video OFICIAL de YouTube que publicó el propio
// artista. No entrega audio: es una capa de identidad y de "a dónde ir a
// buscar el stream", invisible para el usuario.
//
// Límites del sitio (medidos a mano): Fastly devuelve un desafío JS
// ("Client Challenge", 3038 bytes) si se piden ~12 páginas sin pausa, y la URL
// golpeada queda marcada bastante tiempo. Por eso acá: 1 petición cada 3 s,
// caché por página y 10 minutos de pausa al primer desafío. Es deliberadamente
// conservador: el sitio no es una API y castiga las ráfagas.
package lastfm

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

const (
	baseURL = "https://www.last.fm"

	// pausaEntrePeticiones es el mínimo entre dos peticiones reales al sitio.
	pausaEntrePeticiones = 3 * time.Second

	// pausaTrasDesafio es cuánto se deja el sitio en paz cuando aparece el
	// desafío de Fastly. No se reintenta: se devuelve error y la app sigue por
	// sus fuentes normales.
	pausaTrasDesafio = 10 * time.Minute

	// agente es el User-Agent de un navegador real: sin él (o con uno de
	// librería) el sitio responde el desafío casi siempre.
	agente = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
		"(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)

// ErrEnPausa avisa que el sitio está en pausa por un desafío reciente.
var ErrEnPausa = fmt.Errorf("lastfm: en pausa por desafío del sitio") // Client lee páginas de Last.fm con caché, un solo vuelo por página y pausas.
type Client struct {
	http   *http.Client
	limit  *httpclient.RateLimiter
	cache  *cachePaginas
	vuelos *vuelos
	base   string

	mu           sync.Mutex
	desafioHasta time.Time
}

// NewClient crea el cliente. Con `httpClient` nil se arma uno propio.
func NewClient(httpClient *http.Client) *Client {
	if httpClient == nil {
		cfg := httpclient.DefaultConfig()
		cfg.Timeout = 20 * time.Second
		httpClient = httpclient.NewClient(cfg)
	}
	return &Client{
		http: httpClient,
		limit: httpclient.NewRateLimiter(httpclient.RateLimitConfig{
			RequestsPerSecond: 1 / pausaEntrePeticiones.Seconds(),
			Burst:             1,
		}),
		cache:  newCachePaginas(96),
		vuelos: newVuelos(),
		base:   baseURL,
	}
}

// nuevoConBase permite apuntar el cliente a un servidor de prueba.
func nuevoConBase(base string, httpClient *http.Client) *Client {
	c := NewClient(httpClient)
	c.base = base
	return c
}

// Name devuelve "lastfm" para el registro de proveedores.
func (c *Client) Name() string { return "lastfm" }

// EnPausa dice si el sitio sigue castigado por un desafío reciente.
func (c *Client) EnPausa() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return time.Now().Before(c.desafioHasta)
}

// pausar deja el sitio en pausa (se llama al detectar el desafío).
func (c *Client) pausar() {
	c.mu.Lock()
	c.desafioHasta = time.Now().Add(pausaTrasDesafio)
	c.mu.Unlock()
}

// cargar devuelve el HTML de una ruta del sitio, con caché y un solo vuelo por
// ruta: si dos partes de la app piden el mismo álbum a la vez, sale UNA
// petición y las dos reciben lo mismo.
func (c *Client) cargar(ruta string) (string, error) {
	if c.EnPausa() {
		return "", ErrEnPausa
	}
	if cuerpo, ok := c.cache.leer(ruta); ok {
		return cuerpo, nil
	}
	primero, listo := c.vuelos.entrar(ruta)
	if !primero {
		// Otro pedido ya está bajando esta página: se espera y se lee caché.
		c.vuelos.esperarHastaListo(ruta)
		if cuerpo, ok := c.cache.leer(ruta); ok {
			return cuerpo, nil
		}
		return "", fmt.Errorf("lastfm: %s sin resultado", ruta)
	}
	defer listo()

	cuerpo, err := c.bajar(ruta)
	if err != nil {
		return "", err
	}
	c.cache.guardar(ruta, cuerpo)
	return cuerpo, nil
}

// bajar hace la petición real, respetando la pausa entre peticiones.
func (c *Client) bajar(ruta string) (string, error) {
	c.limit.Wait("www.last.fm")
	req, err := http.NewRequest(http.MethodGet, c.base+ruta, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", agente)
	req.Header.Set("Accept", "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "es-ES,es;q=0.9,en;q=0.8")

	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("lastfm: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("lastfm: HTTP %d en %s", resp.StatusCode, ruta)
	}
	datos, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return "", fmt.Errorf("lastfm: %w", err)
	}
	cuerpo := string(datos)
	if esDesafio(cuerpo) {
		c.pausar()
		return "", ErrEnPausa
	}
	return cuerpo, nil
}

// esDesafio reconoce la página de desafío de Fastly: se sirve con HTTP 200 y
// un cuerpo diminuto, así que el tamaño y el título son la firma más estable.
func esDesafio(cuerpo string) bool {
	if strings.Contains(cuerpo, "Client Challenge") {
		return true
	}
	return len(cuerpo) < 8000 && !strings.Contains(cuerpo, "<html")
}
