// ─────────────────────────────────────────────────────────────
// qobuz_busqueda.go — Catálogo de Qobuz para el canal firmado.
//
// Por qué existe: la API de Qobuz NO busca por ISRC (verificado:
// /catalog/search?query=<ISRC> devuelve 0 resultados), así que el único
// camino de ISRC/nombre a una URL de audio es buscar por TEXTO y quedarse
// con la pista cuyo ISRC coincida. Eso es exactamente lo que hace esta
// pieza, y encaja con el rescate que ya existe: la fase de nombre del
// motor de streaming pide `SearchTracks(título + artista)` a cada fuente,
// rankea los resultados y confirma la identidad. Acá los resultados
// traen el ISRC de Qobuz, así que la confirmación es por identidad y no
// por parecido.
//
// Con el canal apagado (sin claves) esto sigue devolviendo el error de
// siempre: flac-rescue continúa sin catálogo propio y nada cambia.
//
// Se conecta con: qobuz_firmado.go y el motor de streaming (fase de
// nombre) / el orquestador de descargas.
// Parte del flujo: rescate de audio por ISRC.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"context"
	"strconv"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// pistaQobuz es lo que se usa de un resultado del catálogo de Qobuz.
type pistaQobuz struct {
	ID        any     `json:"id"`
	ISRC      string  `json:"isrc"`
	Title     string  `json:"title"`
	Duration  float64 `json:"duration"`
	Performer struct {
		Name string `json:"name"`
	} `json:"performer"`
	Album struct {
		Title string `json:"title"`
		Image struct {
			Large string `json:"large"`
			Small string `json:"small"`
		} `json:"image"`
	} `json:"album"`
}

// SearchTracks busca en Qobuz y devuelve pistas con su ISRC, para que el
// llamador pueda confirmar la identidad. Vacío/error cuando el canal está
// apagado (comportamiento histórico de flac-rescue, que no tiene catálogo).
func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	base, _, _, _, _, ok := c.qobuzCredenciales()
	if !ok {
		return nil, errNoCatalogo("búsqueda por nombre")
	}
	if strings.TrimSpace(query) == "" {
		return nil, errNoCatalogo("búsqueda vacía")
	}
	if limit < 1 || limit > 50 {
		limit = 10
	}
	ctx, cancel := context.WithTimeout(context.Background(), presupuestoQobuz)
	defer cancel()

	params := map[string]string{
		"query":  query,
		"limit":  strconv.Itoa(limit),
		"offset": "0",
	}
	var resp struct {
		Tracks struct {
			Items []pistaQobuz `json:"items"`
		} `json:"tracks"`
	}
	if err := c.pedirQobuz(ctx, base, "/catalog/search", params, &resp); err != nil {
		return nil, err
	}
	pistas := make([]provider.TrackResult, 0, len(resp.Tracks.Items))
	for _, item := range resp.Tracks.Items {
		id := idATexto(item.ID)
		if id == "" || strings.TrimSpace(item.Title) == "" {
			continue
		}
		pistas = append(pistas, provider.TrackResult{
			ID:       id,
			Title:    item.Title,
			Artist:   item.Performer.Name,
			Album:    item.Album.Title,
			CoverURL: primeroNoVacio(item.Album.Image.Large, item.Album.Image.Small),
			Duration: int(item.Duration * 1000),
			ISRC:     strings.ToUpper(strings.TrimSpace(item.ISRC)),
			Provider: "flac-rescue",
		})
	}
	return pistas, nil
}
