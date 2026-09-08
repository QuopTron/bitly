package provider

import (
	"strings"
)

func artistaEnTitulo(queryArtist, title string) bool {
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
// A title es solo rejected como un variant cuando su non-original markers (remix,// live, cover...) are absent from the QUERY title too — official titles like
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
	if !strong && artistaEnTitulo(queryArtist, t.Title) {
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
			if artistaEnTitulo(queryArtist, results[i].Title) {
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
