package search

import (
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// ranker scores search results based on title/artist similarity, ISRC presence,
// and version correctness (penalizes covers/remixes when the query doesn't ask
// for them). Reuses the same FieldScore / IsNonOriginalVariant / FoldTrack
// logic the streaming rescue path relies on so search and playback agree on
// what the "original" track is.
type ranker struct {
	queryTitle  string
	queryArtist string
}

// newRanker parses the query into title + artist when the query contains
// a known separator (" - ", " by ", " ft ", etc.), otherwise treats the
// whole string as a title-only search.
func newRanker(query string) *ranker {
	q := strings.TrimSpace(query)

	// Try to split "Artist - Title" or "Title - Artist"
	title, artist := splitTitleArtist(q)
	return &ranker{
		queryTitle:  strings.ToLower(title),
		queryArtist: strings.ToLower(artist),
	}
}

// splitTitleArtist tries to split a search query into (title, artist).
// Common patterns: "Artist - Title", "Title - Artist", "Title ft Artist",
// "Title by Artist". When no separator is found, returns ("", query) so
// the scorer uses full-query title matching.
func splitTitleArtist(q string) (string, string) {
	low := strings.ToLower(q)

	// "Artist - Title" pattern (most common in music searches)
	if idx := strings.Index(low, " - "); idx > 0 {
		return strings.TrimSpace(q[idx+3:]), strings.TrimSpace(q[:idx])
	}
	// "Title by Artist"
	if idx := strings.Index(low, " by "); idx >= 0 {
		return strings.TrimSpace(q[:idx]), strings.TrimSpace(q[idx+4:])
	}
	// "Title ft Artist" / "Title feat Artist"
	for _, sep := range []string{" ft ", " feat ", " featuring ", " ft. ", " feat. "} {
		if idx := strings.Index(low, sep); idx >= 0 {
			return strings.TrimSpace(q[:idx]), strings.TrimSpace(q[idx+len(sep):])
		}
	}
	// No separator — title-only search
	return q, ""
}

// score computes a quality score (0-100) for a track result. Higher = better
// match for the queried track. Uses the same FieldScore / IsNonOriginalVariant
// logic the streaming rescue and download orchestrator rely on.
func (r *ranker) score(tr provider.TrackResult) float64 {
	var s float64

	foldedTitle := provider.FoldTrack(tr.Title)
	foldedQueryArtist := provider.FoldTrack(r.queryArtist)

	// ── Title match (up to +50) ────────────────────────────────────────
	titleScore := provider.FieldScore(r.queryTitle, tr.Title)
	switch {
	case titleScore >= 3:
		s += 50 // exact match
	case titleScore >= 2:
		s += 40 // strong containment / near-full overlap
	case titleScore >= 1:
		s += 15 // weak token overlap — probably a different song
	default:
		s += 0 // no title match
	}

	// ── Non-original variant penalty (remix / live / cover / ...) ───────
	// When the query doesn't contain the marker, penalize results that do.
	if r.queryTitle != "" && provider.IsNonOriginalVariant(tr.Title, r.queryTitle) {
		s -= 30
	}

	// ── Artist match (up to +30) ───────────────────────────────────────
	if r.queryArtist != "" {
		artistScore := provider.FieldScore(r.queryArtist, tr.Artist)
		switch {
		case artistScore >= 3:
			s += 30 // exact artist
		case artistScore >= 2:
			s += 22 // strong containment
		case artistScore >= 1:
			s += 8 // weak overlap
		default:
			// Check if the real artist is inside the title (SoundCloud
			// re-uploads: "Shakira - DAI DAI" uploaded by "uploader")
			if provider.FoldTrack(r.queryArtist) != "" {
				tokens := strings.Fields(foldedQueryArtist)
				for _, tok := range tokens {
					if len(tok) >= 3 && strings.Contains(foldedTitle, tok) {
						s += 15 // artist appears in title → likely the right track
						break
					}
				}
			}
		}
	} else {
		// Title-only query: if the artist field looks like a real artist name
		// (not an uploader/lyrics channel), give a small bonus.
		if tr.Artist != "" && !isUploaderChannel(tr.Artist) {
			s += 5
		}
	}

	// ── ISRC present: +15 (means dedup can work reliably) ──────────────
	if tr.ISRC != "" {
		s += 15
	}

	// ── Duration sanity: +5 if in the typical song range ───────────────
	if tr.Duration > 60000 && tr.Duration < 600000 { // 1m–10m
		s += 5
	}

	// ── Cover art: +3 ──────────────────────────────────────────────────
	if tr.CoverURL != "" {
		s += 3
	}

	// ── Provider trust bonus ───────────────────────────────────────────
	switch strings.ToLower(tr.Provider) {
	case "deezer", "qobuz", "tidal", "amazon":
		s += 12 // premium/official sources
	case "spotify-web", "apple-music":
		s += 8 // metadata-only but authoritative
	case "ytmusic-spotiflac", "youtube":
		s += 6 // YouTube ecosystem
	case "soundcloud":
		s += 2 // lots of re-uploads
	case "musicbrainz":
		s += 1 // metadata only
	}

	return s
}

// isUploaderChannel returns true when an artist name looks like a YouTube /
// SoundCloud re-upload channel rather than a real artist (e.g. "Anna pham",
// "lyrics video", "VEVO", etc.).
func isUploaderChannel(artist string) bool {
	low := strings.ToLower(artist)
	channels := []string{
		"lyrics", "official", "vevo", "topic", "music",
		"video", "channel", "Records", "Entertainment",
	}
	for _, ch := range channels {
		if strings.Contains(low, strings.ToLower(ch)) {
			return true
		}
	}
	return false
}
