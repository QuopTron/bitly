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
