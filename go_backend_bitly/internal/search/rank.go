package search

import "strings"

// Ranker scores and sorts search results by relevance.
type Ranker struct{}

// Score calculates a relevance score for a unified result.
func (r *Ranker) Score(result UnifiedResult, query string) float64 {
	if query == "" {
		return 0
	}

	score := 0.0
	queryLower := strings.ToLower(strings.TrimSpace(query))
	titleLower := strings.ToLower(result.Title)
	artistLower := strings.ToLower(result.Artist)

	// Exact title match (highest priority)
	if strings.EqualFold(result.Title, query) {
		score += 100
	} else if strings.HasPrefix(titleLower, queryLower) {
		score += 80
	} else if strings.Contains(titleLower, queryLower) {
		score += 60
	}

	// Artist match
	if strings.EqualFold(result.Artist, query) {
		score += 50
	} else if strings.HasPrefix(artistLower, queryLower) {
		score += 30
	}

	// ISRC match
	if strings.EqualFold(result.ISRC, query) {
		score += 90
	}

	// Album match boost
	if strings.Contains(strings.ToLower(result.Album), queryLower) {
		score += 20
	}

	// Availability boost
	if result.BestSource != "" {
		score += 10
	}
	if len(result.Sources) > 1 {
		score += 5 * float64(len(result.Sources)-1)
	}

	return score
}

// SortByRelevance sorts unified results by relevance to the query.
func (r *Ranker) SortByRelevance(results []UnifiedResult, query string) []UnifiedResult {
	if len(results) == 0 {
		return results
	}

	scored := make([]struct {
		result UnifiedResult
		score  float64
	}, len(results))

	for i, res := range results {
		scored[i] = struct {
			result UnifiedResult
			score  float64
		}{res, r.Score(res, query)}
	}

	// Simple bubble sort (small result sets)
	for i := 0; i < len(scored); i++ {
		for j := i + 1; j < len(scored); j++ {
			if scored[j].score > scored[i].score {
				scored[i], scored[j] = scored[j], scored[i]
			}
		}
	}

	sorted := make([]UnifiedResult, len(results))
	for i, s := range scored {
		sorted[i] = s.result
	}
	return sorted
}
