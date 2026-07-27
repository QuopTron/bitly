package search

import (
	"strings"
	"unicode"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Deduper removes duplicate results across providers.
type Deduper struct {
	seenISRC  map[string]bool
	seenTitle map[string]bool
}

// NewDeduper creates an empty deduper.
func NewDeduper() *Deduper {
	return &Deduper{
		seenISRC:  make(map[string]bool),
		seenTitle: make(map[string]bool),
	}
}

// IsDuplicate checks if a track result is a duplicate based on ISRC or title.
func (d *Deduper) IsDuplicate(tr provider.TrackResult) bool {
	// ISRC-based dedup (most reliable)
	if tr.ISRC != "" {
		isrc := strings.ToUpper(strings.TrimSpace(tr.ISRC))
		if d.seenISRC[isrc] {
			return true
		}
		d.seenISRC[isrc] = true
		return false
	}

	// Title+Artist-based dedup (fallback)
	key := normalizeTitle(tr.Title) + "|" + normalizeTitle(tr.Artist)
	if d.seenTitle[key] {
		return true
	}
	d.seenTitle[key] = true
	return false
}

// Reset clears the dedup state for a new search.
func (d *Deduper) Reset() {
	d.seenISRC = make(map[string]bool)
	d.seenTitle = make(map[string]bool)
}

// normalizeTitle lowercases and removes punctuation for matching.
func normalizeTitle(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(strings.TrimSpace(s)) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) || unicode.IsSpace(r) {
			b.WriteRune(r)
		}
	}
	return strings.TrimSpace(b.String())
}
