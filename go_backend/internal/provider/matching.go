package provider

import (
	"strings"
	"unicode"
)

// This file holds the canonical "is this the ORIGINAL track" matcher shared by
// the streaming rescue path and the download orchestrator. Keeping it in one
// place avoids drift where one path serves a remix/cover/live version while the
// other rejects it.

// noiseWords are tokens that don't identify a song and may appear on only one
// side of a comparison. Stripping them makes title/artist equality fairer.
var noiseWords = map[string]bool{
	"official": true, "video": true, "audio": true, "lyrics": true, "lyric": true,
	"hd": true, "4k": true, "remaster": true, "remastered": true, "version": true,
	"feat": true, "featuring": true, "ft": true, "with": true, "album": true,
	"single": true, "ep": true,
}

// nonOriginalMarkers are substrings that indicate a version that is NOT the
// original studio cut (remix/live/cover/acoustic/etc). Checked against the raw
// (case-folded) title so they still catch variants that noise stripping would
// otherwise hide ("Song (Live)" -> "song").
var nonOriginalMarkers = []string{
	"remix", "live", "cover", "acoustic", "karaoke", "instrumental",
	"sped up", "spedup", "slowed", "acapella", "orchestral", "tribute",
	"orchestra", "piano", "string quartet", "choir",
}

// FoldTrack lowercases and folds common accented characters for fair
// comparison, keeping letters/digits separated by single spaces.
func FoldTrack(s string) string {
	r := strings.NewReplacer(
		"á", "a", "à", "a", "ä", "a", "â", "a", "ã", "a", "å", "a",
		"é", "e", "è", "e", "ë", "e", "ê", "e",
		"í", "i", "ì", "i", "ï", "i", "î", "i",
		"ó", "o", "ò", "o", "ö", "o", "ô", "o", "õ", "o",
		"ú", "u", "ù", "u", "ü", "u", "û", "u",
		"ñ", "n", "ç", "c",
	)
	s = r.Replace(strings.ToLower(s))
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

// IsNonOriginalTitle reports whether the raw title indicates a version that is
// not the original studio cut (remix/live/cover/acoustic/...).
func IsNonOriginalTitle(rawTitle string) bool {
	low := strings.ToLower(rawTitle)
	for _, m := range nonOriginalMarkers {
		if strings.Contains(low, m) {
			return true
		}
	}
	return false
}

// tokenOverlap returns the fraction of shared tokens between two folded strings.
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

// FieldScore measures how strongly a query field matches a candidate field:
// 3 = equal, 2 = containment, 1 = weak token overlap, 0 = no match.
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
	if tokenOverlap(q, r) >= 0.6 {
		return 1
	}
	return 0
}

// OriginalStrength reports whether the candidate is the ORIGINAL track for the
// query and how strongly (combined title+artist score). The bar is intentionally
// strict: strong artist (>=2) AND strong title (>=2) AND a non-variant title.
// This rejects covers, live/remix/acoustic and wrong-artist re-uploads that a
// looser "something that plays" rule would wrongly rescue.
func OriginalStrength(queryTitle, queryArtist string, t TrackResult) (float64, bool) {
	tt := FieldScore(queryTitle, t.Title)
	aa := FieldScore(queryArtist, t.Artist)
	strong := tt >= 2 && aa >= 2 && !IsNonOriginalTitle(t.Title)
	return tt + aa, strong
}

// BestOriginal picks the strongest candidate that is an ORIGINAL match, or nil.
func BestOriginal(queryTitle, queryArtist string, results []TrackResult) *TrackResult {
	var best *TrackResult
	var bestScore float64
	for i := range results {
		if s, ok := OriginalStrength(queryTitle, queryArtist, results[i]); ok && s > bestScore {
			best = &results[i]
			bestScore = s
		}
	}
	return best
}
