package search

import (
	"testing"
)

func TestRankerExactTitleScore(t *testing.T) {
	r := newRanker("Bohemian Rhapsody")
	tr := makeTrack("1", "ISRC001", "Bohemian Rhapsody", "Queen")

	score := r.score(tr)
	if score < 50 {
		t.Errorf("expected high score (>50) for exact title match, got %f", score)
	}
}

func TestRankerPartialTitleScore(t *testing.T) {
	r := newRanker("Bohemian")
	tr := makeTrack("1", "", "Bohemian Rhapsody", "Queen")

	score := r.score(tr)
	if score < 20 {
		t.Errorf("expected at least 20 for partial match, got %f", score)
	}
}

func TestRankerISRCBonus(t *testing.T) {
	r := newRanker("Some Song")

	trISRC := makeTrack("1", "ISRC001", "Some Song", "Artist")
	trNoISRC := makeTrack("2", "", "Some Song", "Artist")

	scoreWith := r.score(trISRC)
	scoreWithout := r.score(trNoISRC)

	if scoreWith <= scoreWithout {
		t.Error("track with ISRC should score higher")
	}
}

func TestRankerProviderBonus(t *testing.T) {
	r := newRanker("Song")

	trDeezer := makeTrack("1", "", "Song", "Artist")
	trDeezer.Provider = "deezer"
	trYoutube := makeTrack("2", "", "Song", "Artist")
	trYoutube.Provider = "youtube"
	trMusicBrainz := makeTrack("3", "", "Song", "Artist")
	trMusicBrainz.Provider = "musicbrainz"

	if r.score(trDeezer) <= r.score(trYoutube) {
		t.Error("deezer should score higher than youtube")
	}
	if r.score(trYoutube) <= r.score(trMusicBrainz) {
		t.Error("youtube should score higher than musicbrainz")
	}
}

func TestRankerArtistMatchBonus(t *testing.T) {
	r := newRanker("Queen")
	tr := makeTrack("1", "", "We Are the Champions", "Queen")

	score := r.score(tr)
	if score < 15 {
		t.Errorf("expected artist match bonus, got %f", score)
	}
}

func TestRankerEmptyQuery(t *testing.T) {
	r := newRanker("")
	tr := makeTrack("1", "", "Song", "Artist")

	score := r.score(tr)
	if score < 0 {
		t.Errorf("expected non-negative score for empty query, got %f", score)
	}
}

func TestRankerNoMatch(t *testing.T) {
	r := newRanker("ZZZZZZZZ")
	tr := makeTrack("1", "", "Song A", "Artist")

	score := r.score(tr)
	if score > 0 {
		t.Errorf("expected 0 score for no match, got %f", score)
	}
}

func TestRankerDurationBonus(t *testing.T) {
	r := newRanker("Song")

	trWithDur := makeTrack("1", "", "Song", "Artist")
	trWithDur.Duration = 200000
	trNoDur := makeTrack("2", "", "Song", "Artist")

	if r.score(trWithDur) <= r.score(trNoDur) {
		t.Error("track with duration should score higher")
	}
}

func TestRankerCoverBonus(t *testing.T) {
	r := newRanker("Song")

	trWithCover := makeTrack("1", "", "Song", "Artist")
	trWithCover.CoverURL = "http://cover"
	trNoCover := makeTrack("2", "", "Song", "Artist")

	if r.score(trWithCover) <= r.score(trNoCover) {
		t.Error("track with cover should score higher")
	}
}
