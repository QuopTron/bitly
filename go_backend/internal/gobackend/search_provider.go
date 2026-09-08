package gobackend

import (
	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// searchProviderItems searches a single provider and returns FeedItemGo items
// (no JSON serialization — used by streaming search). Track results are
// filtered through RankOriginalCandidates so covers/remixes/wrong-versions
// are rejected before they reach the user's screen.
func searchProviderItems(p provider.Provider, query string, limit int, searchType string) []FeedItemGo {
	items := make([]FeedItemGo, 0)

	// Only skip providers cooled *for search*. Streaming/download rate-limits
	// cool the provider-wide bucket; gating search on that here would make a
	// "Todas"/single-source search come back empty right after a heavy playback
	// session (until the cooldown expires) even though the source's search
	// endpoints are perfectly reachable.
	if cooldown.IsCooledOp(p.Name(), "search") {
		return items
	}

	// Extract query title+artist for relevance filtering.
	queryTitle, queryArtist := splitSearchQuery(query)

	switch searchType {
	case "all", "":
		// Combined search (unfiltered)
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			res, err := ep.CombinedSearch(query, limit)
			if err != nil {
				// Transport/session failure: the source is unhealthy right now.
				// Return fast — a fallback query would fail the same way and
				// only add seconds of dead wait for the user.
				return items
			}
			for _, c := range res {
				item := combinadoAFeedItem(c, ep.Name())
				// Only filter tracks for relevance — albums/artists/playlists
				// are kept as-is (user may want a different album by the same name).
				if item.Type == "track" && queryTitle != "" {
					tr := provider.TrackResult{
						Title:  item.Name,
						Artist: item.Artists,
						ISRC:   item.ISRC,
					}
					if _, ok := provider.OriginalStrength(queryTitle, queryArtist, tr); !ok {
						continue
					}
				}
				items = append(items, item)
			}
			if len(items) > 0 {
				return items
			}
		}
		// Fallback: track search only (only reached when the extension search
		// genuinely succeeded with zero results, or for native providers).
		tracks, err := p.SearchTracks(query, limit)
		if err == nil {
			if queryTitle != "" {
				tracks = provider.RankOriginalCandidates(queryTitle, queryArtist, tracks)
			}
			for _, t := range tracks {
				items = append(items, trackToFeedItem(t, p.Name()))
			}
		}
	case "track", "tracks", "song", "songs":
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			res, err := ep.SearchFiltered(searchType, query, limit)
			if err != nil {
				// Source is down (auth/session/rate-limit): don't burn a second
				// full query on top of the failed one.
				return items
			}
			if len(res) > 0 {
				return combinadosAFeedItems(res, ep.Name())
			}
			// Genuine empty for this filter: fall through to SearchTracks once
			// (some providers only populate the unfiltered search).
		}
		tracks, err := p.SearchTracks(query, limit)
		if err == nil {
			if queryTitle != "" {
				tracks = provider.RankOriginalCandidates(queryTitle, queryArtist, tracks)
			}
			for _, t := range tracks {
				items = append(items, trackToFeedItem(t, p.Name()))
			}
		}
	case "album", "albums":
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if res, err := ep.SearchFiltered(searchType, query, limit); err == nil && len(res) > 0 {
				return combinadosAFeedItems(res, ep.Name())
			}
		}
		albums, err := p.SearchAlbums(query, limit)
		if err == nil {
			for _, a := range albums {
				items = append(items, albumAFeedItem(a, p.Name()))
			}
		}
	case "artist", "artists":
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if res, err := ep.SearchFiltered(searchType, query, limit); err == nil && len(res) > 0 {
				return combinadosAFeedItems(res, ep.Name())
			}
		}
		artists, err := p.SearchArtists(query, limit)
		if err == nil {
			for _, a := range artists {
				items = append(items, artistaAFeedItem(a, p.Name()))
			}
		}
	case "playlist", "playlists":
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if res, err := ep.SearchFiltered(searchType, query, limit); err == nil && len(res) > 0 {
				return combinadosAFeedItems(res, ep.Name())
			}
		}
		playlists, err := p.SearchPlaylists(query, limit)
		if err == nil {
			for _, pl := range playlists {
				items = append(items, playlistAFeedItem(pl, p.Name()))
			}
		}
	}
	return items
}

// combinedToFeedItems converts a slice of CombinedResult to FeedItemGo.
func combinadosAFeedItems(res []provider.CombinedResult, source string) []FeedItemGo {
	items := make([]FeedItemGo, 0, len(res))
	for _, c := range res {
		items = append(items, combinadoAFeedItem(c, source))
	}
	return items
}

// searchRankedAll uses the search engine (ISRC dedup + relevance ranking)
// for track searches across all providers. Falls back to parallel raw search
