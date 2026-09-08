package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

func combinadoAJSON(res []provider.CombinedResult, source string) string {
	items := make([]FeedItemGo, 0, len(res))
	for _, c := range res {
		items = append(items, combinadoAFeedItem(c, source))
	}
	data, _ := json.Marshal(items)
	return string(data)
}

// searchProviderAll performs a single combined search (unfiltered) for the
// provider. Extensions return every result kind with its own item_type, which
// is exactly how SpotiFLAC surfaces tracks/albums/artists/playlists together.
// If el combined call yields nothing (e.g. un non-extension proveedor), we fall// back to a plain track search so the source still returns something.
func searchProviderAll(p provider.Provider, query string, limit int) string {
	items := make([]FeedItemGo, 0)
	// Circuit breaker: skip only if cooled *for search* (not provider-wide,
	// which streaming/download errors trip and would empty this search).
	if cooldown.IsCooledOp(p.Name(), "search") {
		return `[]`
	}
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		if res, err := ep.CombinedSearch(query, limit); err == nil && len(res) > 0 {
			for _, c := range res {
				items = append(items, combinadoAFeedItem(c, ep.Name()))
			}
			data, _ := json.Marshal(items)
			return string(data)
		}
	}
	tracks, err := p.SearchTracks(query, limit)
	if err == nil {
		for _, t := range tracks {
			items = append(items, trackToFeedItem(t, p.Name()))
		}
	}
	data, _ := json.Marshal(items)
	return string(data)
}
