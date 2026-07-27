package search

import (
	"strings"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// ranker scores search results based on multiple signals.
type ranker struct {
	query string
}

// newRanker creates a ranker for the given query.
func newRanker(query string) *ranker {
	return &ranker{query: strings.ToLower(strings.TrimSpace(query))}
}

// score computes a quality score (0-100) for a track result.
func (r *ranker) score(tr provider.TrackResult) float64 {
	var s float64

	q := strings.ToLower(strings.TrimSpace(tr.Title))
	a := strings.ToLower(strings.TrimSpace(tr.Artist))
	query := r.query

	// Exact title match: +50
	if q == query {
		s += 50
	} else if strings.Contains(q, query) || strings.Contains(query, q) {
		s += 30 // partial match
	}

	// ISRC present: +20 (means we can dedup reliably)
	if tr.ISRC != "" {
		s += 20
	}

	// Duration available: +10
	if tr.Duration > 0 {
		s += 10
	}

	// Cover available: +5
	if tr.CoverURL != "" {
		s += 5
	}

	// Provider-based scoring
	switch tr.Provider {
	case "deezer", "qobuz", "tidal":
		s += 10 // premium providers
	case "spotify":
		s += 5 // metadata only
	case "youtube":
		s += 3 // lower priority
	case "musicbrainz":
		s += 1 // metadata only, less reliable
	}

	// Artist match bonus: +15
	if a != "" && (strings.Contains(query, a) || strings.Contains(a, query)) {
		s += 15
	}

	return s
}
