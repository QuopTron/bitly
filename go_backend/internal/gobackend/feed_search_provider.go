package gobackend

import (
	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// searchProvider busca un proveedor y devuelve JSON. Es la frontera para el
// RPC y las rutas del servidor; el trabajo real está en
// searchProviderItemsSync, que devuelve los items ya armados.
func searchProvider(p provider.Provider, query string, limit int, searchType string) string {
	return itemsAJSON(searchProviderItemsSync(p, query, limit, searchType))
}

// searchProviderItemsSync busca un solo proveedor para un tipo dado y devuelve
// los items sin serializar.
//
// Ojo: NO es la misma que searchProviderItems (search_provider.go), que es la
// del camino de streaming y aplica el filtro de originales. Esta conserva
// exactamente la política del camino síncrono (sin filtrar) para no cambiar
// resultados: lo único que cambia acá es que ya no se pasa por JSON en medio.
func searchProviderItemsSync(p provider.Provider, query string, limit int, searchType string) []FeedItemGo {
	items := make([]FeedItemGo, 0)

	// Circuit breaker: skip only if this provider is cooled *for search*. A
	// provider-wide cooldown (tripped by streaming/download rate-limits) must
	// not empty a single-source search — search has its own op bucket.
	if cooldown.IsCooledOp(p.Name(), "search") {
		return items
	}

	switch searchType {
	case "all":
		return searchProviderAllItems(p, query, limit)
	case "track", "tracks", "song", "songs", "album", "albums", "artist", "artists", "playlist", "playlists":
		// For extensions, honour the category filter directly via customSearch
		// with the manifest filter id — this is how SpotiFLAC re-queries a
		// category and returns many more results than the capped "all" mix
		// (50 tracks / 20 albums / 20 artists / 20 playlists).
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if res, err := ep.SearchFiltered(searchType, query, limit); err == nil && len(res) > 0 {
				return combinadosAFeedItems(res, ep.Name())
			}
			// Un vacío filtered resultado es un real vacío (spotiflac shows "sin
			// results"); never fall back to dumping every type here.
			return items
		}
		// Non-extension provider: use the legacy per-type methods below.
	}

	switch searchType {
	case "track", "tracks", "song", "songs":
		tracks, err := p.SearchTracks(query, limit)
		if err == nil {
			for _, t := range tracks {
				items = append(items, trackToFeedItem(t, p.Name()))
			}
		}
	case "album", "albums":
		albums, err := p.SearchAlbums(query, limit)
		if err == nil {
			for _, a := range albums {
				items = append(items, albumAFeedItem(a, p.Name()))
			}
		}
	case "artist", "artists":
		artists, err := p.SearchArtists(query, limit)
		if err == nil {
			for _, a := range artists {
				items = append(items, artistaAFeedItem(a, p.Name()))
			}
		}
	case "playlist", "playlists":
		playlists, err := p.SearchPlaylists(query, limit)
		if err == nil {
			for _, pl := range playlists {
				items = append(items, playlistAFeedItem(pl, p.Name()))
			}
		}
	}

	return items
}
