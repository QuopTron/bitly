package provider

import (
	"strings"
)

func (p *ExtensionProvider) SearchTracks(query string, limit int) ([]TrackResult, error) {
	result, err := p.callOp("search", "searchTracks", query, limit)
	if err == nil {
		if result != nil {
			tracks, cErr := convertirATrackResults(result, p.name)
			p.precargarResultados("getTrack", idsDeTracks(tracks))
			return tracks, cErr
		}
		return nil, nil
	}

	// Only a missing searchTracks method justifies the customSearch fallback;
	// any other error means the extension is unhealthy — don't re-hit it.
	if !strings.Contains(err.Error(), "method searchTracks not found") {
		return nil, err
	}
	opts := map[string]interface{}{"limit": limit, "filter": "song"}
	result, err = p.callOp("search", "customSearch", query, opts)
	if err != nil || result == nil {
		return nil, err
	}
	tracks, cErr := convertirATrackResults(result, p.name)
	p.precargarResultados("getTrack", idsDeTracks(tracks))
	return tracks, cErr
}

// idsDeTracks extrae los ids no vacíos de un resultado de búsqueda para poder
// precargarlos.
func idsDeTracks(tracks []TrackResult) []string {
	ids := make([]string, 0, len(tracks))
	for _, t := range tracks {
		if id := strings.TrimSpace(t.ID); id != "" {
			ids = append(ids, id)
		}
	}
	return ids
}

// idsDeAlbums extrae los ids no vacíos de un resultado de búsqueda de álbumes.
func idsDeAlbums(albums []AlbumResult) []string {
	ids := make([]string, 0, len(albums))
	for _, a := range albums {
		if id := strings.TrimSpace(a.ID); id != "" {
			ids = append(ids, id)
		}
	}
	return ids
}

// precargarResultados adelanta el detalle de los primeros resultados para que
// abrirlos sea instantáneo. Es best-effort y no bloquea la búsqueda.
func (p *ExtensionProvider) precargarResultados(method string, ids []string) {
	p.precargarDetalleEnSegundoPlano(method, ids, maxPrecargaPorBusqueda)
}

// SearchAlbums calls the extension's customSearch with filter "album".
func (p *ExtensionProvider) SearchAlbums(query string, limit int) ([]AlbumResult, error) {
	opts := map[string]interface{}{"limit": limit, "filter": "album"}
	result, err := p.callOp("search", "customSearch", query, opts)
	if err != nil || result == nil {
		return p.buscarTracksComoAlbums(query, limit)
	}
	albums, cErr := convertirAAlbumResults(result, p.name)
	p.precargarResultados("getAlbum", idsDeAlbums(albums))
	return albums, cErr
}

// SearchPlaylists calls the extension's customSearch with filter "playlist".
func (p *ExtensionProvider) SearchPlaylists(query string, limit int) ([]PlaylistResult, error) {
	opts := map[string]interface{}{"limit": limit, "filter": "playlist"}
	result, err := p.callOp("search", "customSearch", query, opts)
	if err != nil || result == nil {
		return nil, nil
	}
	return convertirAPlaylistResults(result, p.name)
}

// SearchArtists calls the extension's customSearch with filter "artist".
func (p *ExtensionProvider) SearchArtists(query string, limit int) ([]ArtistResult, error) {
	opts := map[string]interface{}{"limit": limit, "filter": "artist"}
	result, err := p.callOp("search", "customSearch", query, opts)
	if err != nil || result == nil {
		return nil, nil
	}
	return convertirAArtistResults(result, p.name)
}

// CombinedResult is a single typed search hit from an unfiltered combined
// search. Type mirrors the extension's item_type (track/album/artist/playlist).
// The optional identity campos (ISRC + cross-proveedor ids) son captured cuando// el extension's customSearch output carries ellos so búsqueda/feed resultados mantener// enough identity for local-download matching and fast CheckAvailability
// resolution — mirroring how detail views carry them.
