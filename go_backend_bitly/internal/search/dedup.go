package search

import "strings"

// Deduplicator removes duplicate entries from search results.
type Deduplicator struct{}

// NewDeduplicator creates a new deduplicator.
func NewDeduplicator() *Deduplicator {
	return &Deduplicator{}
}

// Deduplicate removes duplicate results, preferring results with ISRC.
func (d *Deduplicator) Deduplicate(results []RawResult) []RawResult {
	seen := make(map[string]bool)
	var deduped []RawResult

	for _, r := range results {
		key := r.ISRC
		if key == "" {
			key = strings.ToLower(strings.TrimSpace(r.Title + "|" + r.Artist))
		}
		if key == "" || seen[key] {
			continue
		}
		seen[key] = true
		deduped = append(deduped, r)
	}

	return deduped
}
