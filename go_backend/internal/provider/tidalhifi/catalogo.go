// ─────────────────────────────────────────────────────────────
// catalogo.go — Búsqueda y resolución de pistas del canal Tidal HiFi. El
// catálogo expone el ISRC y la duración, así que acá se resuelve con
// IDENTIDAD (ISRC) en vez de con parecido de nombres.
//
// Por qué la búsqueda se verifica: `/tracks?q=` es búsqueda por TEXTO (un
// ISRC devuelve resultados sin relación). Cuando se busca por nombre, el
// resultado solo se acepta si su ISRC coincide con el pedido; si no hay
// ISRC con qué comparar, decide el pipeline con título/artista/duración
// (provider.BestOriginalDuracion).
//
// Se conecta con: client.go (pedir) y descarga.go (lo usa para resolver).
// Parte del flujo: descarga (rescate de FLAC exacto).
// ─────────────────────────────────────────────────────────────

package tidalhifi

import (
	"fmt"
	"net/url"
	"strconv"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// toleranciaDurMs es cuánto puede diferir la duración del catálogo de la
// pedida. El mismo valor que usa el resto del pipeline para el FLAC (4 s).
const toleranciaDurMs = 4000

// absMs es el valor absoluto de una diferencia en milisegundos.
func absMs(v int) int {
	if v < 0 {
		return -v
	}
	return v
}

// pistaTidal es la metadata que devuelve el catálogo.
type pistaTidal struct {
	ID           int    `json:"id"`
	Title        string `json:"title"`
	Duration     int    `json:"duration"`
	ISRC         string `json:"isrc"`
	AudioQuality string `json:"audioQuality"`
	StreamReady  bool   `json:"streamReady"`
	AllowStream  bool   `json:"allowStreaming"`
	Artist       struct {
		Name string `json:"name"`
	} `json:"artist"`
	Album struct {
		Title string `json:"title"`
	} `json:"album"`
}

// aResultado convierte la pista del catálogo al modelo común.
func (p pistaTidal) aResultado() provider.TrackResult {
	return provider.TrackResult{
		ID:       strconv.Itoa(p.ID),
		Title:    p.Title,
		Artist:   p.Artist.Name,
		Album:    p.Album.Title,
		ISRC:     strings.ToUpper(p.ISRC),
		Duration: p.Duration * 1000,
		Provider: "tidal-hifi",
	}
}

// SearchTracks busca por texto y devuelve las pistas del catálogo.
func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	if strings.TrimSpace(query) == "" {
		return nil, fmt.Errorf("tidal-hifi: búsqueda vacía")
	}
	var respuesta struct {
		Items []pistaTidal `json:"items"`
	}
	if err := c.pedir("/tracks?q="+url.QueryEscape(query), &respuesta); err != nil {
		return nil, err
	}
	salida := make([]provider.TrackResult, 0, len(respuesta.Items))
	for _, p := range respuesta.Items {
		if !p.StreamReady || !p.AllowStream {
			continue
		}
		salida = append(salida, p.aResultado())
		if limit > 0 && len(salida) >= limit {
			break
		}
	}
	if len(salida) == 0 {
		return nil, fmt.Errorf("tidal-hifi: sin resultados")
	}
	return salida, nil
}

// GetTrack devuelve la metadata de una pista por su id de Tidal.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	p, err := c.pistaPorID(id)
	if err != nil {
		return nil, err
	}
	r := p.aResultado()
	return &r, nil
}

// pistaPorID trae la pista cruda del catálogo.
func (c *Client) pistaPorID(id string) (pistaTidal, error) {
	if _, err := strconv.Atoi(strings.TrimSpace(id)); err != nil {
		return pistaTidal{}, fmt.Errorf("tidal-hifi: %q no es un id de Tidal", id)
	}
	var p pistaTidal
	if err := c.pedir("/track?id="+url.QueryEscape(id), &p); err != nil {
		return pistaTidal{}, err
	}
	if p.ID == 0 {
		return pistaTidal{}, fmt.Errorf("tidal-hifi: la pista %s no existe", id)
	}
	if !p.StreamReady || !p.AllowStream {
		return pistaTidal{}, fmt.Errorf("tidal-hifi: la pista %s no se puede reproducir", id)
	}
	return p, nil
}

// GetTrackByISRC avisa que este catálogo NO busca por ISRC: su búsqueda es
// por texto (probado: un ISRC devuelve pistas sin relación). El pipeline cae
// entonces a buscar por título+artista y confirma con ISRC + duración (ver
// resolverPista), que es lo que hace segura la elección.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	if strings.TrimSpace(isrc) == "" {
		return nil, fmt.Errorf("tidal-hifi: ISRC vacío")
	}
	return nil, fmt.Errorf("tidal-hifi: el catálogo no busca por ISRC, se usa título+artista")
}

// resolverPista encuentra la pista de Tidal para una canción pedida, con la
// identidad confirmada por ISRC y por duración (tolerancia de [tolerancia]).
//
// Orden: si [id] ya es un id de Tidal se usa directo; si no, se busca por
// título+artista y se acepta SOLO la coincidencia de ISRC (cuando el pedido
// trae ISRC) o el mejor original por duración.
func (c *Client) resolverPista(id, isrc, titulo, artista string, durMS int) (pistaTidal, error) {
	if _, err := strconv.Atoi(strings.TrimSpace(id)); err == nil && strings.TrimSpace(id) != "" {
		p, err := c.pistaPorID(id)
		if err != nil {
			return pistaTidal{}, err
		}
		if isrc != "" && !strings.EqualFold(p.ISRC, isrc) {
			return pistaTidal{}, fmt.Errorf("tidal-hifi: la pista %s es de otro ISRC (%s)", id, p.ISRC)
		}
		// La duración se comprueba ANTES de bajar: armar la canción cuesta
		// decenas de peticiones, y una duración distinta significa otra
		// grabación (directo, remix, versión distinta).
		if durMS > 0 && p.Duration > 0 && absMs(p.Duration*1000-durMS) > toleranciaDurMs {
			return pistaTidal{}, fmt.Errorf("tidal-hifi: la duración no coincide (%ds vs %dms)", p.Duration, durMS)
		}
		return p, nil
	}

	consulta := strings.TrimSpace(titulo + " " + artista)
	if consulta == "" {
		return pistaTidal{}, fmt.Errorf("tidal-hifi: sin id ni nombre con el que buscar")
	}
	resultados, err := c.SearchTracks(consulta, 12)
	if err != nil {
		return pistaTidal{}, err
	}
	for _, r := range resultados {
		if isrc != "" && strings.EqualFold(r.ISRC, isrc) {
			return c.pistaPorID(r.ID)
		}
	}
	if isrc != "" {
		return pistaTidal{}, fmt.Errorf("tidal-hifi: ninguna coincidencia con el ISRC %s", isrc)
	}
	mejor := provider.BestOriginalDuracion(titulo, artista, durMS, resultados)
	if mejor == nil {
		return pistaTidal{}, fmt.Errorf("tidal-hifi: sin coincidencia confiable")
	}
	return c.pistaPorID(mejor.ID)
}
