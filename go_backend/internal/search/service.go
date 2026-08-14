package search

import (
	"sort"
	"sync"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Engine orchestrates multi-provider searches with dedup and ranking.
type Engine struct {
	providers *provider.Registry
	config    Config
}

// New creates a search engine with the given provider registry.
func New(reg *provider.Registry, cfg Config) *Engine {
	return &Engine{
		providers: reg,
		config:    cfg,
	}
}

// SearchTracks searches across all providers, deduplicates, and ranks results.
func (e *Engine) SearchTracks(query string, limit int) (Results, error) {
	if limit < 1 {
		limit = e.config.MaxResults
	}
	providers := e.providers.All()
	deduper := NewDeduper()
	ranker := newRanker(query)

	var mu sync.Mutex
	var results Results
	var wg sync.WaitGroup

	for _, p := range providers {
		wg.Add(1)
		go func(prov provider.Provider) {
			defer wg.Done()
			// Only skip providers cooled *for search*. Downloads/streaming cool
			// their own op buckets or the provider-wide one; a download that
			// rate-limits some providers must never make the next search come
			// back empty — every reachable source is still attempted.
			if cooldown.IsCooledOp(prov.Name(), "search") {
				return
			}
			tracks, err := prov.SearchTracks(query, limit)
			if err != nil {
				return
			}
			mu.Lock()
			for _, t := range tracks {
				if deduper.IsDuplicate(t) {
					continue
				}
				results = append(results, SearchResult{
					Track:  t,
					Score:  ranker.score(t),
					Source: "primary",
				})
			}
			mu.Unlock()
		}(p)
	}
	wg.Wait()

	// Sort by score descending
	sort.Sort(results)

	// Trim to limit
	if len(results) > limit {
		results = results[:limit]
	}

	if results == nil {
		return Results{}, nil
	}
	return results, nil
}
