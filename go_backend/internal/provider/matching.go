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
	"extended", "rework", "remake", "nightcore", "dance edit", "radio edit",
	"club mix", "dub mix", "disco edit", "reprise",
}

// FoldTrack lowercases and folds common accented characters for fair
// comparison, keeping letters/digits separated by single spaces.
// Combining marks (e.g. "n\u0303" instead of "ñ") are dropped so titles that
// differ only in NFD/NFC encoding still match ("Pun\u0303aladas" == "Puñaladas").
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
		// Drop any remaining combining mark so NFC/NFD forms fold identically.
		if unicode.Is(unicode.Mn, r) {
			continue
		}
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

// IsNonOriginalVariant reports whether [rawTitle] is a NON-original version of
// [queryTitle]. A marker like "remix"/"live" is only a signal of a different
// version when the QUERY does not already contain it — "MORNING DEW (DONK)
// REMIX" is the official title of Beyoncé's track, so a candidate carrying the
// same "remix" is the original, not a variant.
func IsNonOriginalVariant(rawTitle, queryTitle string) bool {
	low := strings.ToLower(rawTitle)
	q := strings.ToLower(queryTitle)
	for _, m := range nonOriginalMarkers {
		if strings.Contains(low, m) && !strings.Contains(q, m) {
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
	// same token SET, different order — a strong match, not a weak one.
	if tokenOverlap(q, r) >= 0.85 {
		return 2
	}
	if tokenOverlap(q, r) >= 0.6 {
		return 1
	}
	return 0
}

// artistInTitle reports whether a folded token of [queryArtist] appears as a
// token inside [title]. SoundCloud/YouTube re-uploads put the REAL artist in the
// track title ("Shakira - DAI DAI") while the Artist field holds the uploader
// ("minecraftdiablo") — the title is still the original song.
func artistInTitle(queryArtist, title string) bool {
	qa := FoldTrack(queryArtist)
	if qa == "" {
		return false
	}
	t := FoldTrack(title)
	tokens := strings.Fields(qa)
	for _, tok := range tokens {
		if len(tok) >= 3 && strings.Contains(t, tok) {
			return true
		}
	}
	return false
}

// OriginalStrength reports whether the candidate is the ORIGINAL track for the
// query and how strongly (combined title+artist score). Strong title (>=2) is
// required; the artist may be strong (>=2), OR appear inside the title (common
// SoundCloud re-uploads), OR be exact while the title differs only in token
// order/extra words ("(feat. X) [bonus track]" vs "[bonus track] (feat. X)").
// A title is only rejected as a variant when its non-original markers (remix,
// live, cover...) are absent from the QUERY title too — official titles like
// "MORNING DEW (DONK) REMIX" are accepted.
func OriginalStrength(queryTitle, queryArtist string, t TrackResult) (float64, bool) {
	tt := FieldScore(queryTitle, t.Title)
	aa := FieldScore(queryArtist, t.Artist)
	if tt < 2 {
		return tt + aa, false
	}
	if IsNonOriginalVariant(t.Title, queryTitle) {
		return tt + aa, false
	}
	strong := aa >= 2
	if !strong && artistInTitle(queryArtist, t.Title) {
		strong = true
	}
	return tt + aa, strong
}

// RankOriginalCandidates orders [results] best-first for fallback resolution:
// first every strict ORIGINAL match (strong title + plausible artist), then a
// best-effort pass that keeps candidates whose TITLE strongly matches the query
// even when the Artist field holds an uploader/lyrics channel (SoundCloud/YouTube
// re-uploads: "Manuel Turizo – La Bachata" uploaded by "Anna pham"). Variants
// relative to the query (remix/live/cover when the query lacks them) and tracks
// with a weak title are still excluded, so a different song is never served.
func RankOriginalCandidates(queryTitle, queryArtist string, results []TrackResult) []TrackResult {
	var out []TrackResult
	seen := map[int]bool{}
	// Pass 1: strict originals, best first.
	for i := range results {
		s, ok := OriginalStrength(queryTitle, queryArtist, results[i])
		if ok {
			out = append(out, results[i])
			seen[i] = true
			_ = s
		}
	}
	// Pass 2: best-effort — strong title, non-variant relative to the query,
	// any artist (uploader channels). Only used when no strict original exists.
	if len(out) == 0 {
		var eff []struct {
			idx   int
			score float64
		}
		for i := range results {
			tt := FieldScore(queryTitle, results[i].Title)
			if tt < 2 || IsNonOriginalVariant(results[i].Title, queryTitle) {
				continue
			}
			aa := FieldScore(queryArtist, results[i].Artist)
			if artistInTitle(queryArtist, results[i].Title) {
				aa = 2 // real artist appears inside the title (re-upload)
			}
			eff = append(eff, struct {
				idx   int
				score float64
			}{i, tt + aa})
		}
		// Best first, stable.
		for x := 1; x < len(eff); x++ {
			for y := x; y > 0 && eff[y-1].score < eff[y].score; y-- {
				eff[y-1], eff[y] = eff[y], eff[y-1]
			}
		}
		for _, e := range eff {
			out = append(out, results[e.idx])
		}
	}
	return out
}

// BestOriginal picks the strongest candidate that is an ORIGINAL match, or nil.
func BestOriginal(queryTitle, queryArtist string, results []TrackResult) *TrackResult {
	ranked := RankOriginalCandidates(queryTitle, queryArtist, results)
	if len(ranked) == 0 {
		return nil
	}
	return &ranked[0]
}
