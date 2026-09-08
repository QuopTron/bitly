package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// searchProvider searches a single provider for a given type.
func searchProvider(p provider.Provider, query string, limit int, searchType string) string {
	items := make([]FeedItemGo, 0)

	// Circuit breaker: skip only if this provider is cooled *for search*. A
	// provider-wide cooldown (tripped by streaming/download rate-limits) must
	// not empty a single-source search — search has its own op bucket.
	if cooldown.IsCooledOp(p.Name(), "search") {
		return `[]`
	}

	switch searchType {
	case "all":
		return searchProviderAll(p, query, limit)
	case "track", "tracks", "song", "songs", "album", "albums", "artist", "artists", "playlist", "playlists":
		// For extensions, honour the category filter directly via customSearch
		// with the manifest filter id — this is how SpotiFLAC re-queries a
		// category and returns many more results than the capped "all" mix
		// (50 tracks / 20 albums / 20 artists / 20 playlists).
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if res, err := ep.SearchFiltered(searchType, query, limit); err == nil && len(res) > 0 {
				return combinadoAJSON(res, ep.Name())
			}
			// Un vacío filtered resultado es un real vacío (spotiflac shows "sin
			// results"); never fall back to dumping every type here.
			return `[]`
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

	data, _ := json.Marshal(items)
	return string(data)
}
