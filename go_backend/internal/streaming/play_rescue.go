package streaming

import (
	"fmt"
	"log"
	"strings"
	"unicode"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Circuit breaker: a provider that is rate-limited (HTTP 429) or can only give
// a non-streamable (DRM/encrypted) result gets "cooled down" for a while so the
// rescue/prefetch loop doesn't hammer it repeatedly. Without this, deezer (429)
// was retried for every quality of every queued track, saturating the executor
// and pushing getStreamPackage past the 60s RPC timeout ("Could not resolve
// URI" even though another provider had a valid stream). The breaker is shared
// with search and the download orchestrator via internal/cooldown so a provider
// that 429s anywhere is skipped fast everywhere.


// availableQualities returns the preferred quality plus a set of fallback
// qualities a provider is more likely to support (many providers only expose
// mp3/opus transcodes and fail on FLAC). The preferred one is tried first.
func availableQualities(preferred string) []string {
	seen := map[string]bool{}
	var out []string
	add := func(q string) {
		if q != "" && !seen[q] {
			seen[q] = true
			out = append(out, q)
		}
	}
	add(preferred)
	add("high")
	add("3")
	add("192")
	add("mp3")
	add("128")
	add("low")
	add("flac")
	return out
}

// tryStream intenta obtener stream URL de un provider especifico.
func tryStream(reg *provider.Registry, name, trackID string, track *provider.TrackResult, quality string) (string, error) {
	p := reg.Get(name)
	if p == nil {
		return "", fmt.Errorf("proveedor no encontrado: %s", name)
	}

	candidates := availableQualities(quality)
	for _, q := range candidates {
		if cooldown.IsCooled(name) {
			break
		}
		url, err := p.GetStreamURL(trackID, q)
		if err != nil {
			cooldown.MarkError(name, err.Error())
			continue
		}
		if url != "" && isPlayableStreamURL(url) {
			cooldown.MarkOk(name)
			return url, nil
		}
	}
	if track != nil && track.ID != "" && track.ID != trackID {
		for _, q := range candidates {
			if cooldown.IsCooled(name) {
				break
			}
			url, err := p.GetStreamURL(track.ID, q)
			if err != nil {
				cooldown.MarkError(name, err.Error())
				continue
			}
			if url != "" && isPlayableStreamURL(url) {
				cooldown.MarkOk(name)
				return url, nil
			}
		}
	}
	if track != nil && track.ISRC != "" {
		if trackByISRC, err := p.GetTrackByISRC(track.ISRC); err == nil && trackByISRC != nil {
			for _, q := range candidates {
				if cooldown.IsCooled(name) {
					break
				}
				if url, err := p.GetStreamURL(trackByISRC.ID, q); err != nil {
					cooldown.MarkError(name, err.Error())
				} else if url != "" && isPlayableStreamURL(url) {
					cooldown.MarkOk(name)
					return url, nil
				}
			}
		}
	}
	return "", fmt.Errorf("stream no disponible en %s", name)
}

// rescueStream busca un stream URL en TODOS los providers que streamean.
// Orden: Deezer, Qobuz, Tidal, SoundCloud, YouTube (fallback universal).
// Prueba varias calidades por provider para cubrir providers que solo
// exponen transcodes mp3 (soundcloud etc.) aunque se pida FLAC.
func rescueStream(reg *provider.Registry, track *provider.TrackResult, trackName, artistName, quality string) (string, string, []string) {
	var attempted []string
	candidates := availableQualities(quality)
	for _, name := range streamingProviders {
		p := reg.Get(name)
		if p == nil {
			continue
		}
		if cooldown.IsCooled(name) {
			continue
		}

		if track != nil && track.ISRC != "" {
			found := false
			if trackByISRC, err := p.GetTrackByISRC(track.ISRC); err == nil && trackByISRC != nil {
				for _, q := range candidates {
					if cooldown.IsCooled(name) {
						break
					}
					if url, err := p.GetStreamURL(trackByISRC.ID, q); err != nil {
						cooldown.MarkError(name, err.Error())
					} else if url != "" && isPlayableStreamURL(url) {
						cooldown.MarkOk(name)
						return url, name, nil
					}
				}
				found = true
			}
			if found {
				attempted = append(attempted, name+"(ISRC)")
				continue
			}
		}

		if trackName != "" && artistName != "" {
			found := false
			if results, err := p.SearchTracks(trackName+" "+artistName, 8); err == nil && len(results) > 0 {
				for _, cand := range rankedMatches(trackName, artistName, results) {
					for _, q := range candidates {
						if cooldown.IsCooled(name) {
							break
						}
						if url, err := p.GetStreamURL(cand.ID, q); err != nil {
							cooldown.MarkError(name, err.Error())
						} else if url != "" && isPlayableStreamURL(url) {
							cooldown.MarkOk(name)
							return url, name, attempted
						}
					}
				}
				found = true
			}
			if found {
				attempted = append(attempted, name+"(buscado)")
				continue
			}
		}

		attempted = append(attempted, name)
	}
	return "", "", attempted
}

// asciiFold transliterates common accented chars so matching works across
// providers that may or may not keep accents (e.g. "café" vs "cafe").
func asciiFold(s string) string {
	r := strings.NewReplacer(
		"á", "a", "à", "a", "ä", "a", "â", "a", "ã", "a",
		"é", "e", "è", "e", "ë", "e", "ê", "e",
		"í", "i", "ì", "i", "ï", "i", "î", "i",
		"ó", "o", "ò", "o", "ö", "o", "ô", "o", "õ", "o",
		"ú", "u", "ù", "u", "ü", "u", "û", "u",
		"ñ", "n", "ç", "c",
	)
	return r.Replace(s)
}

// noiseWords are tokens that don't identify a song and can appear in only one
// side of a match (official video/lyrics/remaster etc.). Stripping them makes
// title/artist comparison fairer.
var noiseWords = map[string]bool{
	"official": true, "video": true, "audio": true, "lyrics": true, "lyric": true,
	"hd": true, "4k": true, "remaster": true, "remastered": true, "version": true,
	"feat": true, "featuring": true, "ft": true, "with": true, "live": true,
	"album": true, "single": true, "ep": true, "edit": true, "radio": true,
}

// norm lowercases, folds accents, removes punctuation and noise words, and
// collapses whitespace so strings compare on the meaningful words only.
func norm(s string) string {
	s = asciiFold(strings.ToLower(s))
	var b strings.Builder
	prevSpace := true
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
			prevSpace = false
		} else if !prevSpace {
			b.WriteByte(' ')
			prevSpace = true
		}
	}
	fields := strings.Fields(b.String())
	out := make([]string, 0, len(fields))
	for _, w := range fields {
		if !noiseWords[w] {
			out = append(out, w)
		}
	}
	return strings.Join(out, " ")
}

// tokenOverlap returns the fraction of tokens shared between two strings.
func tokenOverlap(a, b string) float64 {
	ta := strings.Fields(a)
	tb := strings.Fields(b)
	if len(ta) == 0 || len(tb) == 0 {
		return 0
	}
	set := map[string]bool{}
	for _, w := range ta {
		set[w] = true
	}
	hits := 0
	for _, w := range tb {
		if set[w] {
			hits++
		}
	}
	denom := len(ta)
	if len(tb) > denom {
		denom = len(tb)
	}
	return float64(hits) / float64(denom)
}

// titleScore / artistScore: >=2 means equality or containment (strong), 1 is
// weak token overlap, 0 is no match.
func fieldScore(q, r string) float64 {
	if q == "" || r == "" {
		return 0
	}
	if q == r {
		return 3
	}
	if strings.Contains(r, q) || strings.Contains(q, r) {
		return 2
	}
	if tokenOverlap(q, r) >= 0.6 {
		return 1
	}
	return 0
}

// bestMatch picks the search result that best corresponds to the queried
// track/artist, returning the match and its per-field scores so the caller can
// require a strong match before serving a stream (avoid wrong versions/covers).
func bestMatch(queryTitle, queryArtist string, results []provider.TrackResult) (*provider.TrackResult, float64, float64) {
	qt := norm(queryTitle)
	qa := norm(queryArtist)
	var best *provider.TrackResult
	var bestTitle, bestArtist float64
	for i := range results {
		t := fieldScore(qt, norm(results[i].Title))
		a := fieldScore(qa, norm(results[i].Artist))
		if t+a > bestTitle+bestArtist {
			best = &results[i]
			bestTitle = t
			bestArtist = a
		}
	}
	return best, bestTitle, bestArtist
}

// rankedMatches returns the search results sorted best-first by combined
// title+artist score, keeping only candidates that are the ORIGINAL track
// (strong artist AND strong title AND non-variant title via
// provider.OriginalStrength). When no strict original exists it falls back to
// a best-effort pass (strong title + non-variant relative to the query) so the
// rescue can still serve a re-upload of the same song instead of playing
// nothing — different songs (weak title, or covers/remixes the query lacks)
// are still excluded.
func rankedMatches(queryTitle, queryArtist string, results []provider.TrackResult) []provider.TrackResult {
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
