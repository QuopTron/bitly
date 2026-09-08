package provider

import (
	"strings"
)

func solapamientoTokens(a, b string) float64 {
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

// FieldScore measures how strongly a query field matches a candidate field:
// 3 = equal, 2 = containment / near-full token overlap, 1 = weak token overlap,
// 0 = no match.
func FieldScore(q, r string) float64 {
	q = FoldTrack(q)
	r = FoldTrack(r)
	if q == "" || r == "" {
		return 0
	}
	if q == r {
		return 3
	}
	if strings.Contains(r, q) || strings.Contains(q, r) {
		return 2
	}
	// "suave (feat Tokischa) bonus track" vs "suave bonus track feat Tokischa":
	// mismo conjunto de tokens, diferente orden — una coincidencia fuerte, no debil.
	if solapamientoTokens(q, r) >= 0.85 {
		return 2
	}
	if solapamientoTokens(q, r) >= 0.6 {
		return 1
	}
	return 0
}

// artistInTitle reports whether a folded token of [queryArtist] appears as a
// token inside [title]. SoundCloud/YouTube re-uploads put the REAL artist in the
// track title ("Shakira - DAI DAI") while the Artist field holds the uploader
// ("minecraftdiablo") — the title is still the original song.
