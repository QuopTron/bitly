package gobackend

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// searchAllSourceBest searches every provider IN PARALLEL (with a global
// timeout) and returns the combined results from ALL of them, each capped at
// [limit]. A rate-limited (cooled) source is skipped fast. The Flutter side
// groups the returned items by source, so a "Todas" search shows every
// extension's results in its own section instead of only the primary source's
// — and no healthy source is ever left out of the results.
func searchAllSourceBest(query string, limit int, searchType string) string {
	if reg == nil {
		return `[]`
	}
	perSource := limit
	if perSource < 1 {
		perSource = 20
	}

	type namedItems struct {
		name  string
		items []FeedItemGo
	}
	providers := providersBusquedaOrdenados()
	ch := make(chan namedItems, len(providers))
	var wg sync.WaitGroup
	for _, p := range providers {
		// Only skip providers cooled *for search*. Downloads/streaming cool their
		// own op buckets (or the provider-wide one), so a big download that
		// rate-limits a few providers must never leave the next search looking
		// "empty" — search always attempts every reachable source.
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
			res := searchProvider(p, query, perSource, searchType)
			var batch []FeedItemGo
			if err := json.Unmarshal([]byte(res), &batch); err == nil && len(batch) > 0 {
				ch <- namedItems{name: p.Name(), items: batch}
			}
		}(p)
	}
	go func() { wg.Wait(); close(ch) }()

	items := make([]FeedItemGo, 0, len(providers)*perSource)
	timeout := time.After(searchGlobalTimeout)
	collecting := true
	for collecting {
		select {
		case n, ok := <-ch:
			if !ok {
				collecting = false
				break
			}
			items = append(items, n.items...)
		case <-timeout:
			collecting = false
		}
	}
	data, _ := json.Marshal(items)
	return string(data)
}

// searchAllSource searches all providers for a given type, using the
// sequential primary-first strategy (never firing every API in parallel).
// Acepta el manifest filter ids en singular/plural form ("canción"/"canciones",// "song"/"songs", ...) plus "all"/"" for the combined mix.
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
