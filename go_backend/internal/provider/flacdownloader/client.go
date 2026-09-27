// ─────────────────────────────────────────────────────────────
// client.go — RESOLVEDOR DE IDENTIDAD contra la API pública de
// flacdownloader.com.
//
// Qué es flacdownloader: el mismo servicio del que la app ya toma las claves de
// Qobuz para el canal firmado (ver flacrescue/qobuz_claves.go). Además de las
// claves expone búsqueda y detalle del catálogo de Qobuz y de TIDAL:
//
//	GET /api/qobuz/search?q=…   → tracks con ISRC, id, bitDepth, hires
//	GET /api/tidal/search?q=…   → tracks con ISRC, id, lossless, tags
//	GET /api/qobuz/track?id=…   → detalle de un track de Qobuz
//	GET /api/tidal/track?id=…   → detalle de un track de TIDAL
//
// Para qué sirve acá: NO entrega audio. Aporta IDENTIDAD —ISRC, id de Qobuz, id
// de TIDAL, duración— cuando el pedido llega sin ella (un link de YouTube que no
// publica ISRC) o cuando la fuente preferida no la expone. Con esa identidad, el
// rescate entra a la fase exacta por ISRC y al canal FLAC en vez de quedarse con
// el stream lossy por nombre.
//
// Por qué es útil aunque ya existan qobuz-web/tidal-web: esas son extensiones,
// que pueden estar frías, con el buscador desalineado o con la sesión caída. Este
// resolutor es UNA petición HTTP sin sesión y devuelve el ISRC tal como lo
// publica el catálogo. Por eso NO va en proveedoresAudio (no streamea) ni en las
// fuentes de búsqueda (no es un catálogo navegable): vive en streamingProviders
// (identidad de reproducción) y en proveedoresConISRC (derivación).
//
// Se conecta con: play_types.go (streamingProviders) y isrc_derive.go
// (proveedoresConISRC). Parte del flujo: identidad de reproducción.
// ─────────────────────────────────────────────────────────────

package flacdownloader

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

const (
	name = "flacdownloader"
	// baseURL es el host del servicio. Es un campo del Client para poder
	// apuntarlo a un servidor de prueba en los tests.
	baseURL = "https://flacdownloader.com"
	// presupuestoPorPedido acota UNA petición: esto es identidad, no puede
	// comerse el presupuesto del rescate.
	presupuestoPorPedido = 6 * time.Second
)

// Client implementa provider.Provider como SOLO IDENTIDAD (no streamea).
type Client struct {
	http *http.Client
	base string
}

// NewClient crea el resolvedor. [httpClient] nil usa el cliente del proyecto
// (reintentos, breaker por host y timeouts compartidos).
func NewClient(httpClient *http.Client) *Client {
	if httpClient == nil {
		cfg := httpclient.DefaultConfig()
		cfg.Timeout = presupuestoPorPedido
		httpClient = httpclient.NewClient(cfg)
	}
	return &Client{http: httpClient, base: baseURL}
}

// Name implementa provider.Provider.
func (c *Client) Name() string { return name }

// SetBaseURL reescribe el host base (tests).
func (c *Client) SetBaseURL(base string) {
	base = strings.TrimRight(strings.TrimSpace(base), "/")
	if base != "" {
		c.base = base
	}
}

// pistaCruda es un track tal como lo devuelve el servicio. Los mismos nombres
// sirven para Qobuz y para TIDAL (qobuz trae bitDepth/hires, tidal
// lossless/tags; los campos que no aplican llegan vacíos).
type pistaCruda struct {
	Album      string `json:"album"`
	Artist     string `json:"artist"`
	DurationMS int    `json:"durationMs"`
	ID         int64  `json:"id"`
	ISRC       string `json:"isrc"`
	Title      string `json:"title"`
	URL        string `json:"url"`
}

type respuestaBusqueda struct {
	Tracks []pistaCruda `json:"tracks"`
}

// SearchTracks consulta Qobuz y TIDAL EN PARALELO y devuelve los resultados
// combinados (hasta [limit]). Se conserva el orden Qobuz→TIDAL cuando ambos
// contestan: Qobuz es el catálogo que además sostiene el canal firmado.
func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, nil
	}
	if limit <= 0 {
		limit = 8
	}

	type salida struct {
		orden  int
		tracks []pistaCruda
	}
	canal := make(chan salida, 2)
	pedidos := []struct {
		orden int
		ruta  string
	}{
		{0, "/api/qobuz/search"},
		{1, "/api/tidal/search"},
	}
	var wg sync.WaitGroup
	for _, p := range pedidos {
		wg.Add(1)
		go func(orden int, ruta string) {
			defer wg.Done()
			defer func() { recover() }() // un resolvedor caído no puede tumbar la búsqueda
			var resp respuestaBusqueda
			if err := c.buscar(ruta, query, limit, &resp); err != nil {
				return
			}
			canal <- salida{orden: orden, tracks: resp.Tracks}
		}(p.orden, p.ruta)
	}
	wg.Wait()
	close(canal)

	porOrden := make([][]pistaCruda, 2)
	for s := range canal {
		porOrden[s.orden] = s.tracks
	}
	out := make([]provider.TrackResult, 0, limit)
	vistos := map[string]bool{}
	for _, lista := range porOrden {
		for _, p := range lista {
			tr := c.aTrackResult(p)
			if tr.Title == "" {
				continue
			}
			clave := claveDeTrack(tr)
			if vistos[clave] {
				continue
			}
			vistos[clave] = true
			out = append(out, tr)
			if len(out) >= limit {
				return out, nil
			}
		}
	}
	return out, nil
}

// GetTrackByISRC resuelve un ISRC al track del catálogo. Usa Qobuz, que SÍ
// entiende la sintaxis por ISRC (probado en vivo); la búsqueda de TIDAL trata el
// ISRC como texto y devuelve cualquier cosa, así que no se usa para esto.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	isrc = strings.ToUpper(strings.TrimSpace(isrc))
	if len(isrc) < 5 {
		return nil, nil
	}
	var resp respuestaBusqueda
	if err := c.buscar("/api/qobuz/search", isrc, 5, &resp); err != nil {
		return nil, err
	}
	for _, p := range resp.Tracks {
		if !strings.EqualFold(strings.TrimSpace(p.ISRC), isrc) {
			continue
		}
		tr := c.aTrackResult(p)
		return &tr, nil
	}
	return nil, nil
}

// GetTrack acepta un ISRC (no hay catálogo propio de ids).
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	return c.GetTrackByISRC(id)
}

// GetStreamURL deja explícito que este resolvedor NO entrega audio: si alguna
// lista lo incluyera por error en la carrera, falla limpio en vez de fingir un
// stream.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	return "", fmt.Errorf("flacdownloader: solo identidad, no entrega audio")
}

// Los métodos de catálogo no existen: devolver vacío es más honesto que un error
// para los llamadores que recorren proveedores esperando listas.
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	return nil, nil
}
func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	return nil, nil
}
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	return nil, nil
}
func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error)   { return nil, nil }
func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) { return nil, nil }

// aTrackResult mapea una pista cruda al modelo del backend, completando las
// referencias cruzadas (QobuzID/TidalID) que habilitan el CheckAvailability de
// las extensiones sin volver a buscar.
func (c *Client) aTrackResult(p pistaCruda) provider.TrackResult {
	tr := provider.TrackResult{
		Title:    strings.TrimSpace(p.Title),
		Artist:   strings.TrimSpace(p.Artist),
		Album:    strings.TrimSpace(p.Album),
		Duration: p.DurationMS,
		ISRC:     strings.ToUpper(strings.TrimSpace(p.ISRC)),
		Provider: name,
	}
	id := strconv.FormatInt(p.ID, 10)
	switch {
	case strings.Contains(p.URL, "qobuz.com"):
		tr.QobuzID = id
	case strings.Contains(p.URL, "tidal.com"):
		tr.TidalID = id
	}
	// El id propio es el ISRC cuando se conoce (es la identidad de la
	// grabación); si no, uno con el catálogo de origen para no confundirlo con
	// un id de otra fuente.
	if tr.ISRC != "" {
		tr.ID = tr.ISRC
	} else if tr.QobuzID != "" {
		tr.ID = "qobuz:" + id
	} else if tr.TidalID != "" {
		tr.ID = "tidal:" + id
	} else {
		tr.ID = id
	}
	return tr
}

// claveDeTrack deduplica resultados entre los dos catálogos: el ISRC si lo hay,
// y si no el par título/artista normalizado.
func claveDeTrack(t provider.TrackResult) string {
	if t.ISRC != "" {
		return "isrc:" + strings.ToUpper(t.ISRC)
	}
	return "na:" + strings.ToLower(t.Title) + "|" + strings.ToLower(t.Artist)
}

// buscar hace UN GET al servicio y decodifica la respuesta.
func (c *Client) buscar(ruta, q string, limit int, out any) error {
	params := url.Values{}
	params.Set("q", q)
	params.Set("limit", strconv.Itoa(limit))
	destino := c.base + ruta + "?" + params.Encode()

	req, err := http.NewRequest(http.MethodGet, destino, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", httpclient.RandomUserAgent())
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return fmt.Errorf("flacdownloader: %s respondió %d", ruta, resp.StatusCode)
	}
	return json.NewDecoder(io.LimitReader(resp.Body, 4<<20)).Decode(out)
}
