package search

import (
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// interpretacion is one reading of a query: which part is the title and which
// part is the artist. A query written without a separator is ambiguous.
type interpretacion struct {
	title  string
	artist string
}

// maxInterpretaciones bounds how many readings are scored per candidate. A
// query of n tokens generates 1 whole-title reading plus up to 2×(n-1) splits;
// the cap keeps long queries from blowing up the scoring loop.
const maxInterpretaciones = 9

// ranker scores search results based on title/artist similarity, ISRC presence,
// and version correctness (penalizes covers/remixes when the query doesn't ask
// for them). Reuses the same FieldScore / IsNonOriginalVariant / FoldTrack
// logic the streaming rescue path relies on so search and playback agree on
// what the "original" track is.
type ranker struct {
	queryTitle  string
	queryArtist string
	// interpretaciones holds every reading of the query. With a separator there
	// is exactly one; without one ("bad bunny monaco") there are several and
	// each candidate is scored against the best-fitting reading.
	interpretaciones []interpretacion
}

// newRanker parses the query into title + artist when the query contains
// a known separator (" - ", " by ", " ft ", etc.). Without a separator it
// builds every plausible split instead of assuming the whole string is a
// title — see interpretacionesSinSeparador for why that mattered.
func newRanker(query string) *ranker {
	q := strings.TrimSpace(query)

	title, artist := splitTitleArtist(q)
	r := &ranker{
		queryTitle:  strings.ToLower(title),
		queryArtist: strings.ToLower(artist),
	}
	if artist != "" {
		r.interpretaciones = []interpretacion{{title: title, artist: artist}}
		return r
	}
	r.interpretaciones = interpretacionesSinSeparador(q)
	return r
}

// interpretacionesSinSeparador builds the readings of a query that has no
// explicit separator.
//
// Why: "bad bunny monaco" is almost always ARTIST + TITLE, but the whole string
// used to be read as the title. That made a cover literally titled
// "Bad Bunny Monaco" (by a different artist) collect a perfect title match
// (+50) while the real "MONACO" by Bad Bunny only collected containment (+40)
// and no artist credit at all — so the cover won and search showed exactly what
// users complain about: remixes and re-uploaders instead of the real track.
// Measured with the real scores: cover 90 vs real track 80.
//
// The whole string is still offered as a title (some queries really are one
// long title), and both orders are generated because "bohemian rhapsody queen"
// puts the artist last.
func interpretacionesSinSeparador(q string) []interpretacion {
	tokens := strings.Fields(q)
	if len(tokens) < 2 {
		return []interpretacion{{title: q}}
	}

	out := []interpretacion{{title: q}}
	// Longest artist prefix first: "bad bunny monaco" → artist "bad bunny".
	for corte := len(tokens) - 1; corte >= 1 && len(out) < maxInterpretaciones; corte-- {
		out = append(out, interpretacion{
			artist: strings.Join(tokens[:corte], " "),
			title:  strings.Join(tokens[corte:], " "),
		})
	}
	// Artist suffix: "bohemian rhapsody queen" → title "bohemian rhapsody".
	for corte := 1; corte < len(tokens) && len(out) < maxInterpretaciones; corte++ {
		out = append(out, interpretacion{
			title:  strings.Join(tokens[:corte], " "),
			artist: strings.Join(tokens[corte:], " "),
		})
	}
	return out
}

// score computes a quality score (0-100) for a track result. Higher = better
// match for the queried track. The candidate is scored against every reading of
// the query and keeps the best one, so an unseparated query can match either
// "artist + title" or the full string as a title, whichever fits better.
func (r *ranker) score(tr provider.TrackResult) float64 {
	best := 0.0
	for _, i := range r.interpretaciones {
		if s := r.puntaje(i, tr); s > best {
			best = s
		}
	}
	return best
}

// puntaje scores [tr] against one reading of the query.
func (r *ranker) puntaje(i interpretacion, tr provider.TrackResult) float64 {
	var s float64

	// ── Title match (up to +50) ────────────────────────────────────────
	titleScore := provider.FieldScore(i.title, tr.Title)
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
	// When the reading doesn't contain the marker, penalize results that do.
	if i.title != "" && provider.IsNonOriginalVariant(tr.Title, i.title) {
		s -= 30
	}

	// ── Artist match (up to +30) ───────────────────────────────────────
	if i.artist != "" {
		artistScore := provider.FieldScore(i.artist, tr.Artist)
		switch {
		case artistScore >= 3:
			s += 30 // exact artist
		case artistScore >= 2:
			s += 22 // strong containment
		case artistScore >= 1:
			s += 8 // weak overlap
		default:
			// The real artist may live inside the TITLE (SoundCloud/YouTube
			// re-uploads: "Shakira - DAI DAI" uploaded by a channel) — that is
			// still the original recording, so it keeps the bonus, but ONLY
			// when the Artist field looks like a channel/uploader. A real artist
			// name there means a different recording, and that candidate simply
			// does not collect the artist credit (the entry that DOES have the
			// credit outscores it through the reading above).
			if provider.EsCanalDeResubida(tr.Artist) && artistaEnTitulo(tr.Title, i.artist) {
				s += 15
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

// artistaEnTitulo reports whether a folded token of [artist] appears inside
// [title]. It is the re-upload convention where the real artist goes in the
// title ("Shakira - DAI DAI") while the Artist field holds the uploader.
func artistaEnTitulo(title, artist string) bool {
	titulo := provider.FoldTrack(title)
	if titulo == "" {
		return false
	}
	for _, tok := range strings.Fields(provider.FoldTrack(artist)) {
		if len(tok) >= 3 && strings.Contains(titulo, tok) {
			return true
		}
	}
	return false
}
