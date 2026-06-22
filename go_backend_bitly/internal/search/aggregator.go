package search

// Aggregator combines results from multiple providers into unified results.
type Aggregator struct{}

// NewAggregator creates a new aggregator.
func NewAggregator() *Aggregator {
	return &Aggregator{}
}

// Aggregate groups raw results by ISRC or title+artist and merges metadata.
func (a *Aggregator) Aggregate(results []RawResult) []UnifiedResult {
	// Group by ISRC
	groups := make(map[string][]RawResult)
	var noISRC []RawResult
	for _, r := range results {
		if r.ISRC != "" {
			groups[r.ISRC] = append(groups[r.ISRC], r)
		} else {
			noISRC = append(noISRC, r)
		}
	}

	var unified []UnifiedResult
	for isrc, items := range groups {
		u := UnifiedResult{
			ID:      isrc,
			ISRC:    isrc,
			Sources: make(map[string]SourceAvailability),
		}
		for _, item := range items {
			if u.Title == "" {
				u.Title = item.Title
				u.Artist = item.Artist
				u.Album = item.Album
				u.DurationMs = item.Duration
			}
			u.Sources[item.Source] = SourceAvailability{
				Available: true,
			}
		}
		unified = append(unified, u)
	}

	// Add items without ISRC individually
	for _, r := range noISRC {
		unified = append(unified, UnifiedResult{
			ID:         r.ID,
			Title:      r.Title,
			Artist:     r.Artist,
			Album:      r.Album,
			DurationMs: r.Duration,
			ISRC:       r.ISRC,
			Sources: map[string]SourceAvailability{
				r.Source: {Available: true},
			},
		})
	}

	return unified
}
