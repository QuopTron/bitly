package streaming

import (
	"log"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// matchesRankeados ordena los resultados de una búsqueda POR NOMBRE quedándose
// solo con el original. [queryDurationMS] (0 = desconocida) desempata entre
// candidatos que empatan en título+artista — el caso de YouTube/SoundCloud, que
// no exponen ISRC y tienen la misma canción subida varias veces con distinta
// duración (video oficial vs. audio vs. re-subido).
func matchesRankeados(queryTitle, queryArtist string, queryDurationMS int, results []provider.TrackResult) []provider.TrackResult {
	ranked := provider.RankOriginalCandidatesDuracion(queryTitle, queryArtist, queryDurationMS, results)
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
