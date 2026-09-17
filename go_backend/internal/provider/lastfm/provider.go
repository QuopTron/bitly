// ─────────────────────────────────────────────────────────────
// provider.go — Last.fm como proveedor del registro.
//
// Es un proveedor de SOLO METADATA: no entrega audio, así que queda fuera
// de la búsqueda visible y del orden de streaming (ver
// gobackend/search_fuentes.go y download/orchestrator_fallback.go). Existe
// para dos usos internos:
//
//   - identidad: nombres canónicos (el sitio corrige "DTMF" contra "DtMF")
//     para cruzar resultados entre extensiones;
//   - video oficial: el id de YouTube que publicó el propio artista, que
//     permite pedir el stream SIN búsqueda por nombre.
//
// Implementa la interfaz provider.Provider para poder registrarse como
// cualquier otra fuente, pero lo que no aplica (ISRC, stream) devuelve un
// error explícito en vez de datos inventados.
// ─────────────────────────────────────────────────────────────

package lastfm

import (
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// SearchTracks resuelve una consulta libre y devuelve candidatos con su video
// oficial. No se ofrece en la búsqueda visible: la usan la identidad y el
// rescate cuando algo falla.
func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	pistas, err := c.Buscar(query)
	if err != nil {
		return nil, err
	}
	if limit < 1 {
		limit = 10
	}
	resultados := make([]provider.TrackResult, 0, len(pistas))
	for _, p := range pistas {
		resultados = append(resultados, provider.TrackResult{
			ID:        idPista(p),
			Title:     p.Nombre,
			Artist:    p.Artistas,
			Duration:  p.DuracionMs,
			Provider:  "lastfm",
			YouTubeID: p.YouTubeID,
		})
		if len(resultados) == limit {
			break
		}
	}
	return resultados, nil
}

// GetTrack no aplica: el sitio no tiene un id propio de pista.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	return nil, fmt.Errorf("lastfm: %q sin ficha por id (se resuelve por nombre)", id)
}

// GetTrackByISRC no aplica: el sitio no publica ISRC.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	return nil, fmt.Errorf("lastfm: sin ISRC (%s)", isrc)
}

// GetAlbum no aplica: para el tracklist se usa PistasDeAlbum(artista, álbum),
// que necesita los dos nombres.
func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	return nil, fmt.Errorf("lastfm: %q sin ficha por id (usar PistasDeAlbum)", id)
}

// GetArtist devuelve el artista con sus géneros.
func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	generos, err := c.GenerosDeArtista(id)
	if err != nil {
		return nil, err
	}
	return &provider.ArtistResult{
		ID: id, Name: strings.TrimSpace(id), Provider: "lastfm", Genres: generos,
	}, nil
}

// SearchAlbums no aplica como catálogo (no se ofrece en la búsqueda).
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	return nil, nil
}

// SearchArtists no aplica como catálogo (no se ofrece en la búsqueda).
func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	return nil, nil
}

// SearchPlaylists no aplica: el sitio no expone playlists.
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	return nil, nil
}

// GetStreamURL no aplica: Last.fm no entrega audio.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	return "", fmt.Errorf("lastfm: no entrega audio")
}

// idPista arma un id estable y comparable para una pista del sitio.
func idPista(p Pista) string {
	return "lastfm:" + claveComparacion(p.Artistas+" "+p.Nombre)
}
