package streaming

import (
	"log"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func matchesRankeados(queryTitle, queryArtist string, results []provider.TrackResult) []provider.TrackResult {
	ranked := provider.RankOriginalCandidates(queryTitle, queryArtist, results)
	if len(results) > 0 && len(ranked) == 0 {
		log.Printf("[rescue] %q / %q: %d results, sin candidato reproducible. Candidatos:",
			queryTitle, queryArtist, len(results))
		for i := range results {
			tt := provider.FieldScore(queryTitle, results[i].Title)
			aa := provider.FieldScore(queryArtist, results[i].Artist)
			log.Printf("  [%d] t=%.0f a=%.0f | %q | %q | nonorig=%v", i, tt, aa,
				results[i].Title, results[i].Artist, provider.IsNonOriginalTitle(results[i].Title))
		}
	}
	return ranked
}
