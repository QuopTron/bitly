package streaming

import (
	"fmt"
	"log"
	"strings"
	"sync"
	"time"
	"unicode"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Circuit breaker: a provider that is rate-limited (HTTP 429) or can only give
// a non-streamable (DRM/encrypted) result gets "cooled down" for a while so the
// rescue/prefetch loop doesn't hammer it repeatedly. Without this, deezer (429)
// was retried for every quality of every queued track, saturating the executor
// and pushing getStreamPackage past the 60s RPC timeout ("Could not resolve
// URI" even though another provider had a valid stream).
var (
	cooldownMu       sync.Mutex
	providerCooldown = map[string]time.Time{}
)

func isProviderCooled(name string) bool {
	cooldownMu.Lock()
	defer cooldownMu.Unlock()
	return time.Now().Before(providerCooldown[name])
}

func markProviderError(name, errMsg string) {
	if !strings.Contains(errMsg, "429") &&
		!strings.Contains(errMsg, "temporarily unavailable") &&
		!strings.Contains(errMsg, "client decryption") &&
		!strings.Contains(errMsg, "encriptado") {
		return
	}
	cooldownMu.Lock()
	defer cooldownMu.Unlock()
	providerCooldown[name] = time.Now().Add(60 * time.Second)
}

func markProviderOk(name string) {
	cooldownMu.Lock()
	defer cooldownMu.Unlock()
	delete(providerCooldown, name)
}


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
		if isProviderCooled(name) {
			break
		}
		url, err := p.GetStreamURL(trackID, q)
		if err != nil {
			markProviderError(name, err.Error())
			continue
		}
		if url != "" && isPlayableStreamURL(url) {
			markProviderOk(name)
			return url, nil
		}
	}
	if track != nil && track.ID != "" && track.ID != trackID {
		for _, q := range candidates {
			if isProviderCooled(name) {
				break
			}
			url, err := p.GetStreamURL(track.ID, q)
			if err != nil {
				markProviderError(name, err.Error())
				continue
			}
			if url != "" && isPlayableStreamURL(url) {
				markProviderOk(name)
				return url, nil
			}
		}
	}
	if track != nil && track.ISRC != "" {
		if trackByISRC, err := p.GetTrackByISRC(track.ISRC); err == nil && trackByISRC != nil {
			for _, q := range candidates {
				if isProviderCooled(name) {
					break
				}
				if url, err := p.GetStreamURL(trackByISRC.ID, q); err != nil {
					markProviderError(name, err.Error())
				} else if url != "" && isPlayableStreamURL(url) {
					markProviderOk(name)
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
		if isProviderCooled(name) {
			continue
		}

		if track != nil && track.ISRC != "" {
			found := false
			if trackByISRC, err := p.GetTrackByISRC(track.ISRC); err == nil && trackByISRC != nil {
				for _, q := range candidates {
					if isProviderCooled(name) {
						break
					}
					if url, err := p.GetStreamURL(trackByISRC.ID, q); err != nil {
						markProviderError(name, err.Error())
					} else if url != "" && isPlayableStreamURL(url) {
						markProviderOk(name)
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
						if isProviderCooled(name) {
							break
						}
						if url, err := p.GetStreamURL(cand.ID, q); err != nil {
							markProviderError(name, err.Error())
						} else if url != "" && isPlayableStreamURL(url) {
							markProviderOk(name)
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
// provider.OriginalStrength). Non-original versions (covers, remixes, live,
// wrong-artist re-uploads) are excluded so rescue never serves a different
// song than the one the user asked for, even if it means nothing to play.
func rankedMatches(queryTitle, queryArtist string, results []provider.TrackResult) []provider.TrackResult {
	type scored struct {
		idx           int
		title, artist float64
	}
	qt := norm(queryTitle)
	qa := norm(queryArtist)
	var sc []scored
	for i := range results {
		t := fieldScore(qt, norm(results[i].Title))
		a := fieldScore(qa, norm(results[i].Artist))
		// Keep only the ORIGINAL track: strong artist + strong title and no
		// variant markers (remix/live/cover/acoustic/...). Everything else —
		// covers, remixes, wrong artist — is dropped so we never play a
		// different song than requested.
		if _, ok := provider.OriginalStrength(queryTitle, queryArtist, results[i]); ok {
			sc = append(sc, scored{idx: i, title: t, artist: a})
		}
	}
	if len(results) > 0 && len(sc) == 0 {
		log.Printf("[rescue] %q / %q: %d results, NINGUNO es la original. Candidatos:",
			queryTitle, queryArtist, len(results))
		for i := range results {
			tt := provider.FieldScore(queryTitle, results[i].Title)
			aa := provider.FieldScore(queryArtist, results[i].Artist)
			log.Printf("  [%d] t=%.0f a=%.0f | %q | %q | nonorig=%v", i, tt, aa,
				results[i].Title, results[i].Artist, provider.IsNonOriginalTitle(results[i].Title))
		}
	}
	// Stable sort by descending combined score.
	for i := 1; i < len(sc); i++ {
		for j := i; j > 0 && sc[j-1].title+sc[j-1].artist < sc[j].title+sc[j].artist; j-- {
			sc[j-1], sc[j] = sc[j], sc[j-1]
		}
	}
	out := make([]provider.TrackResult, 0, len(sc))
	for _, s := range sc {
		out = append(out, results[s.idx])
	}
	return out
}
