package search

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func TestRankerEmptyQuery(t *testing.T) {
	r := newRanker("")
	tr := provider.TrackResult{
		ID: "1", Title: "Song", Artist: "Artist",
	}

	score := r.score(tr)
	if score < 0 {
		t.Errorf("expected non-negative score for empty query, got %f", score)
	}
}

func TestRankerNoMatch(t *testing.T) {
	r := newRanker("ZZZZZZZZ")
	tr := provider.TrackResult{
		ID: "1", Title: "Song A", Artist: "Artist",
	}

	score := r.score(tr)
	// With no title/artist match, only small bonuses remain (uploader check, provider, etc.)
	// The important thing is it's much lower than an actual match.
	matchScore := r.score(provider.TrackResult{
		ID: "1", Title: "ZZZZZZZZ", Artist: "Someone",
	})
	if score >= matchScore {
		t.Errorf("no-match score (%f) should be lower than match score (%f)", score, matchScore)
	}
}

func TestRankerDurationBonus(t *testing.T) {
	r := newRanker("Song")

	trWithDur := provider.TrackResult{
		ID: "1", Title: "Song", Artist: "Artist", Duration: 200000,
	}
	trNoDur := provider.TrackResult{
		ID: "2", Title: "Song", Artist: "Artist",
	}

	if r.score(trWithDur) <= r.score(trNoDur) {
		t.Error("track with duration should score higher")
	}
}

func TestRankerCoverBonus(t *testing.T) {
	r := newRanker("Song")

	trWithCover := provider.TrackResult{
		ID: "1", Title: "Song", Artist: "Artist", CoverURL: "http://cover",
	}
	trNoCover := provider.TrackResult{
		ID: "2", Title: "Song", Artist: "Artist",
	}

	if r.score(trWithCover) <= r.score(trNoCover) {
		t.Error("track with cover should score higher")
	}
}

func TestRankerRemixPenalty(t *testing.T) {
	r := newRanker("Song Name")

	original := provider.TrackResult{
		ID: "1", Title: "Song Name", Artist: "Artist",
	}
	remix := provider.TrackResult{
		ID: "2", Title: "Song Name (Remix)", Artist: "Artist",
	}

	origScore := r.score(original)
	remixScore := r.score(remix)

	if remixScore >= origScore {
		t.Errorf("remix (%f) should score lower than original (%f)", remixScore, origScore)
	}
}

func TestRankerRemixNotPenalizedWhenQueried(t *testing.T) {
	// When the user searches for "Song Name remix", the remix is the original
	r := newRanker("Song Name remix")

	remix := provider.TrackResult{
		ID: "1", Title: "Song Name (Remix)", Artist: "Artist",
	}
	original := provider.TrackResult{
		ID: "2", Title: "Song Name", Artist: "Artist",
	}

	remixScore := r.score(remix)
	origScore := r.score(original)

	if remixScore < origScore {
		t.Errorf("queried remix (%f) should score >= non-matching original (%f)", remixScore, origScore)
	}
}

func TestSplitTitleArtist(t *testing.T) {
	tests := []struct {
		input  string
		title  string
		artist string
	}{
		{"Artist - Title", "Title", "Artist"},
		{"Title by Artist", "Title", "Artist"},
		{"Title ft Artist", "Title", "Artist"},
		{"Title feat Artist", "Title", "Artist"},
		{"Just a title", "Just a title", ""},
		{"", "", ""},
	}

	for _, tt := range tests {
		title, artist := splitTitleArtist(tt.input)
		if title != tt.title || artist != tt.artist {
			t.Errorf("splitTitleArtist(%q) = (%q, %q), want (%q, %q)",
				tt.input, title, artist, tt.title, tt.artist)
		}
	}
}
