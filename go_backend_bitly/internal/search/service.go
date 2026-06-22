package search

import (
	"context"
	"sort"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

type Service struct {
	registry *core.ProviderRegistry
	agg      *Aggregator
	dedup    *Deduplicator
	ranker   *Ranker
	cache    *Cache
}

func NewService(registry *core.ProviderRegistry) *Service {
	return &Service{
		registry: registry,
		agg:      NewAggregator(),
		dedup:    NewDeduplicator(),
		ranker:   &Ranker{},
		cache:    NewCache(5*time.Minute, 100),
	}
}

func (s *Service) Search(ctx context.Context, req SearchRequest) (*SearchResult, error) {
	if cached, ok := s.cache.Get(req.Query + "|" + req.Type); ok {
		return cached, nil
	}

	start := time.Now()
	providers := s.registry.GetAllSearchProviders()
	var allRaw []RawResult
	var sourcesQueried, sourcesResponded []string

	for _, p := range providers {
		sourcesQueried = append(sourcesQueried, p.ID())
		results, err := p.Search(req.Query, req.Limit)
		if err != nil {
			continue
		}
		sourcesResponded = append(sourcesResponded, p.ID())
		for _, r := range results {
			allRaw = append(allRaw, RawResult{
				ID:       r.ID,
				Title:    r.Title,
				Artist:   r.Artist,
				Album:    r.Album,
				Duration: r.Duration,
				ISRC:     r.ISRC,
				Source:   r.Source,
				CoverURL: r.CoverURL,
			})
		}
	}

	allRaw = s.dedup.Deduplicate(allRaw)
	unified := s.agg.Aggregate(allRaw)
	sort.Slice(unified, func(i, j int) bool {
		return s.ranker.Score(unified[i], req.Query) > s.ranker.Score(unified[j], req.Query)
	})

	result := &SearchResult{
		Mode:             SearchModeUnified,
		Query:            req.Query,
		Type:             req.Type,
		Unified:          unified,
		BySource:         groupBySource(allRaw),
		Single:           allRaw,
		SourcesQueried:   sourcesQueried,
		SourcesResponded: sourcesResponded,
		DurationMs:       time.Since(start).Milliseconds(),
	}

	if req.Query != "" {
		s.cache.Set(req.Query+"|"+req.Type, result)
	}
	return result, nil
}

func groupBySource(results []RawResult) map[string][]RawResult {
	groups := make(map[string][]RawResult)
	for _, r := range results {
		groups[r.Source] = append(groups[r.Source], r)
	}
	for k := range groups {
		set := make(map[string]bool)
		var deduped []RawResult
		for _, r := range groups[k] {
			key := r.ID + "|" + strings.ToLower(r.Title+r.Artist)
			if !set[key] {
				set[key] = true
				deduped = append(deduped, r)
			}
		}
		groups[k] = deduped
	}
	return groups
}
