package gobackend

import (
	"encoding/json"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// =========================================================================
// Types matching Flutter's FeedSection / FeedItem JSON schema
// =========================================================================

// FeedItemGo is the JSON shape Flutter expects from search & feed endpoints.
type FeedItemGo struct {
	ID          string `json:"id"`
	Type        string `json:"type"`
	Name        string `json:"name"`
	Artists     string `json:"artists,omitempty"`
	CoverURL    string `json:"cover_url,omitempty"`
	Source      string `json:"source,omitempty"`
	AlbumID     string `json:"album_id,omitempty"`
	AlbumName   string `json:"album_name,omitempty"`
	DurationMs  int    `json:"duration_ms,omitempty"`
	ReleaseDate string `json:"release_date,omitempty"`
	TotalTracks int    `json:"total_tracks,omitempty"`
	Owner       string `json:"owner,omitempty"`
	ISRC        string `json:"isrc,omitempty"`
}

// FeedSectionGo is the JSON shape Flutter expects for feed section groups.
type FeedSectionGo struct {
	Source      string        `json:"source"`
	DisplayName string        `json:"display_name"`
	Title       string        `json:"title"`
	Items       []FeedItemGo  `json:"items"`
}

// =========================================================================
// HELPERS
// =========================================================================

// trackToFeedItem converts a provider.TrackResult to a FeedItemGo.
func trackToFeedItem(t provider.TrackResult, source string) FeedItemGo {
	return FeedItemGo{
		ID:         t.ID,
		Type:       "track",
		Name:       t.Title,
		Artists:    t.Artist,
		CoverURL:   t.CoverURL,
		Source:     source,
		AlbumID:    t.AlbumID,
		AlbumName:  t.Album,
		DurationMs: t.Duration,
		ISRC:       t.ISRC,
	}
}

// albumToFeedItem converts a provider.AlbumResult to a FeedItemGo.
func albumToFeedItem(a provider.AlbumResult, source string) FeedItemGo {
	return FeedItemGo{
		ID:          a.ID,
		Type:        "album",
		Name:        a.Title,
		Artists:     a.Artist,
		CoverURL:    a.CoverURL,
		Source:      source,
		ReleaseDate: a.ReleaseDate,
		TotalTracks: a.TrackCount,
	}
}

// artistToFeedItem converts a provider.ArtistResult to a FeedItemGo.
func artistToFeedItem(a provider.ArtistResult, source string) FeedItemGo {
	return FeedItemGo{
		ID:       a.ID,
		Type:     "artist",
		Name:     a.Name,
		CoverURL: a.PictureURL,
		Source:   source,
	}
}

// playlistToFeedItem converts a provider.PlaylistResult to a FeedItemGo.
func playlistToFeedItem(p provider.PlaylistResult, source string) FeedItemGo {
	return FeedItemGo{
		ID:          p.ID,
		Type:        "playlist",
		Name:        p.Title,
		CoverURL:    p.CoverURL,
		Source:      source,
		TotalTracks: p.TrackCount,
		Owner:       p.Creator,
	}
}

// combinedToFeedItem converts a provider.CombinedResult (from an unfiltered
// extension search) to a FeedItemGo, keeping the item's own type so the UI can
// group tracks/albums/artists/playlists separately (SpotiFLAC principle).
func combinedToFeedItem(c provider.CombinedResult, source string) FeedItemGo {
	return FeedItemGo{
		ID:          c.ID,
		Type:        c.Type,
		Name:        c.Name,
		Artists:     c.Artists,
		CoverURL:    c.CoverURL,
		Source:      source,
		AlbumID:     c.AlbumID,
		AlbumName:   c.AlbumName,
		DurationMs:  c.Duration,
		ReleaseDate: c.ReleaseDate,
		TotalTracks: c.TotalTracks,
		Owner:       c.Owner,
	}
}

// =========================================================================
// GetHomeFeed — returns a JSON array of FeedSectionGo grouped by provider
// =========================================================================

// GetSources returns the list of user-facing sources (providers/extensions)
// registered in the backend. Internal metadata/rescue-only providers
// (musicbrainz) and natives superseded by an extension (youtube, replaced by
// ytmusic-spotiflac) are excluded so the UI shows no duplicate/empty bubbles.
func GetSources() string {
	if reg == nil {
		return `[]`
	}
	hidden := map[string]bool{
		"musicbrainz": true, // metadata/rescue only, no feed content
		"youtube":     true, // superseded by the ytmusic-spotiflac extension
	}
	names := make([]string, 0, 12)
	for _, n := range reg.Names() {
		if hidden[n] {
			continue
		}
		names = append(names, n)
	}
	data, err := json.Marshal(names)
	if err != nil {
		return `[]`
	}
	return string(data)
}

func GetHomeFeed(_locale string) string {
	if reg == nil {
		return `[]`
	}

	// Home-feed timeouts. Sources like spotify-web do several sequential HTTP
	// calls (session info → access token → client token → browse REST) before
	// returning sections, which can easily exceed a short cap. SpotiFLAC uses a
	// generous 60s window for getHomeFeed; we match that here so every
	// home-feed-capable source gets a real chance. The Flutter UI keeps showing
	// cached content while this refreshes, so a longer window doesn't blank.
	const (
		feedSourceTimeout = 60 * time.Second
		feedTotalTimeout  = 70 * time.Second
	)

	all := make([]FeedSectionGo, 0)
	var mu sync.Mutex
	var wg sync.WaitGroup

	// 1. Extension providers getHomeFeed() — en PARALELO con timeout individual.
	//    Only sources that declare the homeFeed capability are attempted
	//    (SpotiFLAC's hasHomeFeed), so providers without a feed (e.g. pandora,
	//    soundcloud) are skipped cleanly instead of timing out.
	for _, p := range reg.All() {
		ep, ok := p.(*provider.ExtensionProvider)
		if !ok {
			continue
		}
		if !ep.HomeFeedEnabled() {
			log.Printf("[feed] %s: skipped (no homeFeed capability)", ep.Name())
			continue
		}
		sourceName := ep.Name()
		wg.Add(1)
		go func(prov *provider.ExtensionProvider, name string) {
			defer wg.Done()
			defer func() {
				if rec := recover(); rec != nil {
					log.Printf("[feed] %s: panic: %v", name, rec)
				}
			}()

			type feedResult struct {
				sections []provider.HomeFeedSection
				err      error
			}
			ch := make(chan feedResult, 1)
			go func() {
				secs, err := prov.GetHomeFeed()
				ch <- feedResult{sections: secs, err: err}
			}()

			var sections []provider.HomeFeedSection
			select {
			case res := <-ch:
				if res.err != nil {
					log.Printf("[feed] %s: error: %v", name, res.err)
					return
				}
				if len(res.sections) == 0 {
					log.Printf("[feed] %s: no sections returned", name)
					return
				}
				sections = res.sections
			case <-time.After(feedSourceTimeout):
				log.Printf("[feed] %s: timed out after %s", name, feedSourceTimeout)
				return
			}

			mu.Lock()
			total := 0
			for _, s := range sections {
				items := make([]FeedItemGo, 0, len(s.Items))
				for _, item := range s.Items {
					coverURL := item.ThumbURL
					// Fallback: YouTube thumbnail de video ID (11 chars = video ID)
					if coverURL == "" && len(item.ItemID) == 11 {
						coverURL = "https://img.youtube.com/vi/" + item.ItemID + "/mqdefault.jpg"
					}
					// Si no hay cover, dejar vacío para que Flutter muestre placeholder
					items = append(items, FeedItemGo{
						ID:         item.ItemID,
						Type:       item.ItemType,
						Name:       item.Name,
						Artists:    item.Artists,
						DurationMs: item.DurationMs,
						AlbumID:    item.AlbumID,
						AlbumName:  item.AlbumName,
						CoverURL:   coverURL,
						Source:     prov.Name(),
					})
				}
				total += len(items)
				all = append(all, FeedSectionGo{
					Source:      prov.Name(),
					DisplayName: prov.Name(),
					Title:       s.Title,
					Items:       items,
				})
			}
			mu.Unlock()
			log.Printf("[feed] %s: %d sections, %d items", name, len(sections), total)
		}(ep, sourceName)
	}

	// Esperar extensiones (max feedTotalTimeout total)
	extDone := make(chan struct{}, 1)
	go func() {
		wg.Wait()
		extDone <- struct{}{}
	}()
	select {
	case <-extDone:
	case <-time.After(feedTotalTimeout):
		log.Printf("[feed] overall timed out after %s", feedTotalTimeout)
	}

	// 2. (Removed) The old "popular" fallback used native search to fabricate
	// generic sections. Following the SpotiFLAC pattern, the home feed now
	// comes entirely from each extension's getHomeFeed() real sections above.
	// Sections without real content are simply omitted.

	data, err := json.Marshal(all)
	if err != nil {
		return `[]`
	}
	return string(data)
}

// =========================================================================
// Search — unified search returning []FeedItemGo JSON
// =========================================================================

// Search accepts a single JSON payload from Flutter (the Kotlin dispatch serializes
// the entire Map arguments as one JSON string). It parses the payload internally.
func Search(payload string) string {
	if reg == nil {
		return `[]`
	}

	var params struct {
		Query  string `json:"query"`
		Limit  int    `json:"limit"`
		Source string `json:"source"`
		Type   string `json:"type"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `[]`
	}

	query := params.Query
	limit := params.Limit
	if limit < 1 {
		limit = 20
	}
	source := params.Source
	searchType := params.Type

	// If searching all providers, use searchAll (parallel with 15s timeout)
	if source == "" {
		return searchAllSource(query, limit, searchType)
	}

	// Specific source: find the provider and search it directly
	p := reg.Get(source)
	if p == nil {
		for _, name := range reg.Names() {
			if strings.EqualFold(name, source) {
				p = reg.Get(name)
				break
			}
		}
	}
	if p == nil {
		return `[]`
	}

	return searchProvider(p, query, limit, searchType)
}

// orderedSearchProviders returns providers ordered for a "Todas" search:
// the manifest primary search extension first (SpotiFLAC's
// defaultSearchExtension — our deezer), then every other registered provider.
// This lets the sequential search below try the best source first and only
// fall through when it returns nothing (e.g. deezer rate-limited), instead of
// firing every search API in parallel and tripping 429s on each keystroke.
func orderedSearchProviders() []provider.Provider {
	if reg == nil {
		return nil
	}
	all := reg.All()
	primary := map[string]bool{}
	for _, e := range bundledExts {
		if e.Search.Primary {
			primary[e.ID] = true
		}
	}
	ordered := make([]provider.Provider, 0, len(all))
	seen := map[string]bool{}
	add := func(p provider.Provider) {
		if p == nil || seen[p.Name()] {
			return
		}
		seen[p.Name()] = true
		ordered = append(ordered, p)
	}
	for _, p := range all {
		if primary[p.Name()] {
			add(p)
		}
	}
	for _, p := range all {
		if !primary[p.Name()] {
			add(p)
		}
	}
	return ordered
}

// searchAllSourceBest searches providers sequentially in primary-first order
// and stops once enough results are collected. A rate-limited (cooled) source
// is skipped fast, and a healthy primary fills the screen — the others only
// step in when the primary returns nothing. This replaces the old
// fire-all-APIs-in-parallel mix that blanked search results on 429s.
func searchAllSourceBest(query string, limit int, searchType string) string {
	items := make([]FeedItemGo, 0, limit)
	sourcesUsed := 0
	for _, p := range orderedSearchProviders() {
		if cooldown.IsCooled(p.Name()) {
			continue
		}
		res := searchProvider(p, query, limit, searchType)
		var batch []FeedItemGo
		if err := json.Unmarshal([]byte(res), &batch); err == nil && len(batch) > 0 {
			items = append(items, batch...)
			sourcesUsed++
			// Primary source healthy: its results fill the screen (SpotiFLAC
			// searches a single primary source). Fall through only when the
			// primary came back empty or a second source is needed to fill.
			if sourcesUsed >= 2 || len(items) >= limit {
				break
			}
		}
	}
	data, _ := json.Marshal(items)
	return string(data)
}

// searchAllSource searches all providers for a given type, using the
// sequential primary-first strategy (never firing every API in parallel).
// Accepts the manifest filter ids in singular/plural form ("track"/"tracks",
// "song"/"songs", ...) plus "all"/"" for the combined mix.
func searchAllSource(query string, limit int, searchType string) string {
	switch searchType {
	case "track", "tracks", "song", "songs", "album", "albums", "artist", "artists", "playlist", "playlists":
		return searchAllSourceBest(query, limit, searchType)
	case "all", "":
		return searchAllSourceBest(query, limit, "all")
	default:
		return `[]`
	}
}

// searchProvider searches a single provider for a given type.
func searchProvider(p provider.Provider, query string, limit int, searchType string) string {
	items := make([]FeedItemGo, 0)

	// Circuit breaker: a provider cooling down from rate-limits returns fast.
	if cooldown.IsCooled(p.Name()) {
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
				return combinedToJSON(res, ep.Name())
			}
			// An empty filtered result is a real empty (SpotiFLAC shows "no
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
				items = append(items, albumToFeedItem(a, p.Name()))
			}
		}
	case "artist", "artists":
		artists, err := p.SearchArtists(query, limit)
		if err == nil {
			for _, a := range artists {
				items = append(items, artistToFeedItem(a, p.Name()))
			}
		}
	case "playlist", "playlists":
		playlists, err := p.SearchPlaylists(query, limit)
		if err == nil {
			for _, pl := range playlists {
				items = append(items, playlistToFeedItem(pl, p.Name()))
			}
		}
	}

	data, _ := json.Marshal(items)
	return string(data)
}

func combinedToJSON(res []provider.CombinedResult, source string) string {
	items := make([]FeedItemGo, 0, len(res))
	for _, c := range res {
		items = append(items, combinedToFeedItem(c, source))
	}
	data, _ := json.Marshal(items)
	return string(data)
}

// searchProviderAll performs a single combined search (unfiltered) for the
// provider. Extensions return every result kind with its own item_type, which
// is exactly how SpotiFLAC surfaces tracks/albums/artists/playlists together.
// If the combined call yields nothing (e.g. a non-extension provider), we fall
// back to a plain track search so the source still returns something.
func searchProviderAll(p provider.Provider, query string, limit int) string {
	items := make([]FeedItemGo, 0)
	// Circuit breaker: a provider cooling down from rate-limits returns fast.
	if cooldown.IsCooled(p.Name()) {
		return `[]`
	}
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		if res, err := ep.CombinedSearch(query, limit); err == nil && len(res) > 0 {
			for _, c := range res {
				items = append(items, combinedToFeedItem(c, ep.Name()))
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
func searchRawToJSON[T any](raw []namedResult[T], converter func(T, string) FeedItemGo) string {
	items := make([]FeedItemGo, 0)
	for _, r := range raw {
		for _, v := range r.Results {
			items = append(items, converter(v, r.Provider))
		}
	}
	data, _ := json.Marshal(items)
	return string(data)
}
