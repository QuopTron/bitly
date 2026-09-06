package gobackend

import (
	"encoding/json"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

const searchGlobalTimeout = 4 * time.Second

// =========================================================================
// STREAMING SEARCH BUFFER
// =========================================================================

// searchStreamState holds partial results for a streaming search session.
// Flutter polls GetSearchStreamResults() to receive results incrementally
// as each provider completes, instead of waiting for the full 9s timeout.
type searchStreamState struct {
	mu         sync.Mutex
	items      []FeedItemGo
	done       bool
	generation int64
}

var currentSearchStream = &searchStreamState{}

// SearchStream starts a parallel search across all providers and returns
// immediately. Results accumulate in a buffer that Flutter reads via
// GetSearchStreamResults(). Returns the generation ID for this search.
func SearchStream(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}

	var params struct {
		Query  string `json:"query"`
		Limit  int    `json:"limit"`
		Source string `json:"source"`
		Type   string `json:"type"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}

	query := params.Query
	limit := params.Limit
	if limit < 1 {
		limit = 20
	}
	source := params.Source
	searchType := params.Type

	currentSearchStream.mu.Lock()
	currentSearchStream.generation++
	gen := currentSearchStream.generation
	currentSearchStream.items = nil
	currentSearchStream.done = false
	currentSearchStream.mu.Unlock()

	go runSearchStream(gen, query, limit, source, searchType)

	data, _ := json.Marshal(map[string]interface{}{
		"generation": gen,
	})
	return string(data)
}

// runSearchStream executes the search in background, appending results to the
// shared buffer as each provider completes. Providers run in parallel; results
// are deduplicated by ISRC (for tracks) or by ID (for collections).
func runSearchStream(gen int64, query string, limit int, source string, searchType string) {
	if source == "" {
		// "Todas": search all providers, primary first
		searchAllStreamProviders(gen, query, limit, searchType)
	} else {
		// Single source
		p := reg.Get(source)
		if p == nil {
			for _, name := range reg.Names() {
				if equalFold(name, source) {
					p = reg.Get(name)
					break
				}
			}
		}
		if p != nil {
			items := searchProviderItems(p, query, limit, searchType)
			appendSearchStream(gen, items)
		}
	}

	currentSearchStream.mu.Lock()
	if currentSearchStream.generation == gen {
		currentSearchStream.done = true
	}
	currentSearchStream.mu.Unlock()
}

// searchAllStreamProviders runs all providers in parallel (primary first),
// appending results to the stream buffer as each one completes. Unlike
// searchAllSourceBest which waits for ALL providers before returning, this
// streams results incrementally so Flutter can show partial results.
func searchAllStreamProviders(gen int64, query string, limit int, searchType string) {
	if reg == nil {
		return
	}

	providers := orderedSearchProviders()
	perSource := limit
	if perSource < 1 {
		perSource = 20
	}

	type namedBatch struct {
		name  string
		items []FeedItemGo
	}
	ch := make(chan namedBatch, len(providers))

	var wg sync.WaitGroup
	for _, p := range providers {
		if cooldown.IsCooledOp(p.Name(), "search") {
			continue
		}
		wg.Add(1)
		go func(p provider.Provider) {
			defer wg.Done()
			defer func() {
				if rec := recover(); rec != nil {
					// Never crash the app if a provider panics mid-search.
				}
			}()
			items := searchProviderItems(p, query, perSource, searchType)
			if len(items) > 0 {
				ch <- namedBatch{name: p.Name(), items: items}
			}
		}(p)
	}
	go func() { wg.Wait(); close(ch) }()

	timeout := time.After(searchGlobalTimeout)
	for {
		select {
		case batch, ok := <-ch:
			if !ok {
				return
			}
			appendSearchStream(gen, batch.items)
		case <-timeout:
			return
		}
	}
}

// appendSearchStream deduplicates and appends items to the stream buffer.
func appendSearchStream(gen int64, items []FeedItemGo) {
	currentSearchStream.mu.Lock()
	defer currentSearchStream.mu.Unlock()
	if currentSearchStream.generation != gen {
		return // search was superseded by a new query
	}
	for _, item := range items {
		if isDuplicateSearchItem(currentSearchStream.items, item) {
			continue
		}
		currentSearchStream.items = append(currentSearchStream.items, item)
	}
}

// isDuplicateSearchItem checks if an item already exists in the list.
// For tracks: dedup by ISRC, then by title+artist.
// For collections: dedup by type+id.
func isDuplicateSearchItem(existing []FeedItemGo, item FeedItemGo) bool {
	if item.Type == "track" {
		if item.ISRC != "" {
			for _, e := range existing {
				if e.Type == "track" && e.ISRC == item.ISRC {
					return true
				}
			}
		}
		// Fallback: title+artist dedup
		for _, e := range existing {
			if e.Type == "track" && e.Name == item.Name && e.Artists == item.Artists {
				return true
			}
		}
		return false
	}
	// Albums/artists/playlists: dedup by type+id
	for _, e := range existing {
		if e.Type == item.Type && e.ID == item.ID {
			return true
		}
	}
	return false
}

// GetSearchStreamResults returns the accumulated results for the current
// streaming search. Flutter polls this every ~500ms.
// Response: { items: [...], done: bool, generation: int64 }
func GetSearchStreamResults() string {
	currentSearchStream.mu.Lock()
	gen := currentSearchStream.generation
	items := make([]FeedItemGo, len(currentSearchStream.items))
	copy(items, currentSearchStream.items)
	done := currentSearchStream.done
	currentSearchStream.mu.Unlock()

	data, _ := json.Marshal(map[string]interface{}{
		"items":      items,
		"done":       done,
		"generation": gen,
	})
	return string(data)
}

func equalFold(a, b string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := 0; i < len(a); i++ {
		ca, cb := a[i], b[i]
		if ca >= 'A' && ca <= 'Z' {
			ca += 32
		}
		if cb >= 'A' && cb <= 'Z' {
			cb += 32
		}
		if ca != cb {
			return false
		}
	}
	return true
}

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
				item := combinedToFeedItem(c, ep.Name())
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
				return combinedToFeedItems(res, ep.Name())
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
				return combinedToFeedItems(res, ep.Name())
			}
		}
		albums, err := p.SearchAlbums(query, limit)
		if err == nil {
			for _, a := range albums {
				items = append(items, albumToFeedItem(a, p.Name()))
			}
		}
	case "artist", "artists":
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if res, err := ep.SearchFiltered(searchType, query, limit); err == nil && len(res) > 0 {
				return combinedToFeedItems(res, ep.Name())
			}
		}
		artists, err := p.SearchArtists(query, limit)
		if err == nil {
			for _, a := range artists {
				items = append(items, artistToFeedItem(a, p.Name()))
			}
		}
	case "playlist", "playlists":
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if res, err := ep.SearchFiltered(searchType, query, limit); err == nil && len(res) > 0 {
				return combinedToFeedItems(res, ep.Name())
			}
		}
		playlists, err := p.SearchPlaylists(query, limit)
		if err == nil {
			for _, pl := range playlists {
				items = append(items, playlistToFeedItem(pl, p.Name()))
			}
		}
	}
	return items
}

// combinedToFeedItems converts a slice of CombinedResult to FeedItemGo.
func combinedToFeedItems(res []provider.CombinedResult, source string) []FeedItemGo {
	items := make([]FeedItemGo, 0, len(res))
	for _, c := range res {
		items = append(items, combinedToFeedItem(c, source))
	}
	return items
}

// searchRankedAll uses the search engine (ISRC dedup + relevance ranking)
// for track searches across all providers. Falls back to parallel raw search
// for non-track types.
func searchRankedAll(query string, limit int, searchType string) []FeedItemGo {
	switch searchType {
	case "track", "tracks", "song", "songs":
		return searchRankedTracks(query, limit)
	default:
		// For non-track types, use parallel search with dedup
		return searchAllParallelDedup(query, limit, searchType)
	}
}

// searchRankedTracks uses search.Engine for ISRC dedup + relevance ranking.
func searchRankedTracks(query string, limit int) []FeedItemGo {
	if searchEngine == nil {
		return nil
	}
	results, err := searchEngine.SearchTracks(query, limit)
	if err != nil {
		return nil
	}
	items := make([]FeedItemGo, 0, len(results))
	for _, r := range results {
		items = append(items, trackToFeedItem(r.Track, r.Source))
	}
	return items
}

// searchAllParallelDedup runs all providers in parallel for non-track types
// with cross-provider dedup by ID.
func searchAllParallelDedup(query string, limit int, searchType string) []FeedItemGo {
	if reg == nil {
		return nil
	}

	providers := orderedSearchProviders()
	perSource := limit
	if perSource < 1 {
		perSource = 20
	}

	type namedBatch struct {
		items []FeedItemGo
	}
	ch := make(chan namedBatch, len(providers))

	var wg sync.WaitGroup
	for _, p := range providers {
		if cooldown.IsCooledOp(p.Name(), "search") {
			continue
		}
		wg.Add(1)
		go func(p provider.Provider) {
			defer wg.Done()
			defer func() {
				if rec := recover(); rec != nil {
					// Never crash
				}
			}()
			items := searchProviderItems(p, query, perSource, searchType)
			if len(items) > 0 {
				ch <- namedBatch{items: items}
			}
		}(p)
	}
	go func() { wg.Wait(); close(ch) }()

	allItems := make([]FeedItemGo, 0, len(providers)*perSource)
	timeout := time.After(searchGlobalTimeout)
	for {
		select {
		case batch, ok := <-ch:
			if !ok {
				return allItems
			}
			for _, item := range batch.items {
				if !isDuplicateSearchItem(allItems, item) {
					allItems = append(allItems, item)
				}
			}
		case <-timeout:
			return allItems
		}
	}
}

// namedResult holds one provider's search results for generic searchByProvider.
type namedResult[T any] struct {
	Provider string `json:"provider"`
	Results  []T    `json:"results"`
}

// namedTrack holds one provider's track results (JSON field "tracks").
type namedTrack struct {
	Provider string                 `json:"provider"`
	Tracks   []provider.TrackResult `json:"tracks"`
}

// searchAll runs fn for every registered provider in parallel.
// Returns after searchGlobalTimeout or when all providers finish.
func searchAll[T any](query string, limit int,
	fn func(provider.Provider, string, int) ([]T, error),
) []namedResult[T] {
	return searchAllWithTimeout(query, limit, fn, searchGlobalTimeout)
}

// searchAllWithTimeout runs fn for every registered provider in parallel.
// Returns after the given timeout or when all providers finish.
func searchAllWithTimeout[T any](query string, limit int,
	fn func(provider.Provider, string, int) ([]T, error),
	searchTimeout time.Duration,
) []namedResult[T] {
	if reg == nil {
		return nil
	}
	providers := reg.All()
	if len(providers) == 0 {
		return nil
	}

	type item struct {
		name string
		data []T
	}
	ch := make(chan item, len(providers))

	var wg sync.WaitGroup
	for _, p := range providers {
		wg.Add(1)
		go func(prov provider.Provider) {
			defer wg.Done()
			defer func() {
				if rec := recover(); rec != nil {
					// Don't crash the app if a provider panics
				}
			}()
			// Circuit breaker: skip only providers cooled for search (not
			// provider-wide, which streaming/download errors trip). Search has its
			// own "search" op bucket so a playback rate-limit never empties the
			// next search.
			if cooldown.IsCooledOp(prov.Name(), "search") {
				return
			}
			res, err := fn(prov, query, limit)
			if err == nil && len(res) > 0 {
				ch <- item{name: prov.Name(), data: res}
			}
		}(p)
	}

	go func() {
		wg.Wait()
		close(ch)
	}()

	results := make([]namedResult[T], 0)
	timeout := time.After(searchTimeout)
	collecting := true
	for collecting {
		select {
		case r, ok := <-ch:
			if !ok {
				collecting = false
				break
			}
			results = append(results, namedResult[T]{
				Provider: r.name,
				Results:  r.data,
			})
		case <-timeout:
			collecting = false
		}
	}
	return results
}

// =========================================================================
// SEARCH
// =========================================================================

func SearchTracks(query string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	raw := searchAll(query, 10, func(p provider.Provider, q string, l int) ([]provider.TrackResult, error) {
		return p.SearchTracks(q, l)
	})
	results := make([]namedTrack, 0, len(raw))
	for _, r := range raw {
		results = append(results, namedTrack{Provider: r.Provider, Tracks: r.Results})
	}
	data, _ := json.Marshal(results)
	return string(data)
}

func searchByProvider[T any](query string, limit int,
	fn func(provider.Provider, string, int) ([]T, error),
) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	results := searchAll(query, limit, fn)
	data, _ := json.Marshal(results)
	return string(data)
}

func SearchAlbums(query string) string {
	return searchByProvider(query, 5, func(p provider.Provider, q string, l int) ([]provider.AlbumResult, error) {
		return p.SearchAlbums(q, l)
	})
}

func SearchPlaylists(query string) string {
	return searchByProvider(query, 5, func(p provider.Provider, q string, l int) ([]provider.PlaylistResult, error) {
		return p.SearchPlaylists(q, l)
	})
}

func SearchArtists(query string) string {
	return searchByProvider(query, 5, func(p provider.Provider, q string, l int) ([]provider.ArtistResult, error) {
		return p.SearchArtists(q, l)
	})
}

// =========================================================================
// METADATA
// =========================================================================

func GetTrack(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ProviderName string `json:"providerName"`
		TrackID      string `json:"trackID"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	track, err := p.GetTrack(params.TrackID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(track)
	return string(data)
}

func GetAlbum(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ProviderName string `json:"providerName"`
		AlbumID      string `json:"albumID"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	album, err := p.GetAlbum(params.AlbumID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(album)
	return string(data)
}

func GetArtist(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ProviderName string `json:"providerName"`
		ArtistID     string `json:"artistID"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	artist, err := p.GetArtist(params.ArtistID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(artist)
	return string(data)
}

func ResolveISRC(isrc string) string {
	if searchEngine == nil {
		return `{"error":"no inicializado"}`
	}
	results, err := searchEngine.SearchTracks(`isrc:"`+isrc+`"`, 5)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(results)
	return string(data)
}

// splitSearchQuery parses a search query like "Artist - Title" or "Title ft Artist"
// into (title, artist). When no separator is found the whole query is treated as
// a title-only search with an empty artist.
func splitSearchQuery(q string) (string, string) {
	low := strings.ToLower(q)
	// "Artist - Title"
	if idx := strings.Index(low, " - "); idx > 0 {
		return strings.TrimSpace(q[idx+3:]), strings.TrimSpace(q[:idx])
	}
	// "Title by Artist"
	if idx := strings.Index(low, " by "); idx >= 0 {
		return strings.TrimSpace(q[:idx]), strings.TrimSpace(q[idx+4:])
	}
	// "Title ft Artist" / "Title feat Artist"
	for _, sep := range []string{" ft ", " feat ", " featuring ", " ft. ", " feat. "} {
		if idx := strings.Index(low, sep); idx >= 0 {
			return strings.TrimSpace(q[:idx]), strings.TrimSpace(q[idx+len(sep):])
		}
	}
	return q, ""
}
