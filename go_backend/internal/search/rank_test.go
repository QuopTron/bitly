package search

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func TestRankerExactTitleScore(t *testing.T) {
	r := newRanker("Bohemian Rhapsody")
	tr := provider.TrackResult{
		ID: "1", ISRC: "ISRC001", Title: "Bohemian Rhapsody", Artist: "Queen",
	}

	score := r.score(tr)
	if score < 50 {
		t.Errorf("expected high score (>50) for exact title match, got %f", score)
	}
}

func TestRankerPartialTitleScore(t *testing.T) {
	// "Bohemian" in query → containment in "Bohemian Rhapsody" → score 40
	r := newRanker("Bohemian")
	tr := provider.TrackResult{
		ID: "1", Title: "Bohemian Rhapsody", Artist: "Queen",
	}

	score := r.score(tr)
	if score < 30 {
		t.Errorf("expected at least 30 for partial match, got %f", score)
	}
}

func TestRankerISRCBonus(t *testing.T) {
	r := newRanker("Some Song")

	trISRC := provider.TrackResult{
		ID: "1", ISRC: "ISRC001", Title: "Some Song", Artist: "Artist",
	}
	trNoISRC := provider.TrackResult{
		ID: "2", Title: "Some Song", Artist: "Artist",
	}

	scoreWith := r.score(trISRC)
	scoreWithout := r.score(trNoISRC)

	if scoreWith <= scoreWithout {
		t.Errorf("track with ISRC (%f) should score higher than without (%f)", scoreWith, scoreWithout)
	}
}

func TestRankerProviderBonus(t *testing.T) {
	r := newRanker("Song")

	trDeezer := provider.TrackResult{
		ID: "1", Title: "Song", Artist: "Artist", Provider: "deezer",
	}
	trYoutube := provider.TrackResult{
		ID: "2", Title: "Song", Artist: "Artist", Provider: "youtube",
	}
	trMusicBrainz := provider.TrackResult{
		ID: "3", Title: "Song", Artist: "Artist", Provider: "musicbrainz",
	}

	scoreDeezer := r.score(trDeezer)
	scoreYoutube := r.score(trYoutube)
	scoreMB := r.score(trMusicBrainz)

	if scoreDeezer <= scoreYoutube {
		t.Errorf("deezer (%f) should score higher than youtube (%f)", scoreDeezer, scoreYoutube)
	}
	if scoreYoutube <= scoreMB {
		t.Errorf("youtube (%f) should score higher than musicbrainz (%f)", scoreYoutube, scoreMB)
	}
}

func TestRankerArtistMatchBonus(t *testing.T) {
	// Query with artist separator: "Queen - We Are the Champions"
	r := newRanker("We Are the Champions by Queen")
	tr := provider.TrackResult{
		ID: "1", Title: "We Are the Champions", Artist: "Queen",
	}

	score := r.score(tr)
	if score < 60 {
		t.Errorf("expected strong score for title+artist match, got %f", score)
	}
}

func TestRankerArtistInTitleBonus(t *testing.T) {
	// SoundCloud re-upload: artist is in the title
	r := newRanker("Shakira - La Bicicleta")
	tr := provider.TrackResult{
		ID: "1", Title: "Shakira - La Bicicleta", Artist: "uploader",
	}

	score := r.score(tr)
	if score < 30 {
		t.Errorf("expected decent score for artist-in-title match, got %f", score)
	}
}

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
