package search

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func makeTrack(id, isrc, title, artist string) provider.TrackResult {
	return provider.TrackResult{
		ID:     id,
		ISRC:   isrc,
		Title:  title,
		Artist: artist,
	}
}

func TestDeduperByISRC(t *testing.T) {
	d := NewDeduper()

	if d.IsDuplicate(makeTrack("1", "ISRC001", "Song A", "Artist")) {
		t.Error("first ISRC should not be duplicate")
	}
	if !d.IsDuplicate(makeTrack("2", "ISRC001", "Song A (Remastered)", "Artist")) {
		t.Error("same ISRC should be duplicate")
	}
	if d.IsDuplicate(makeTrack("3", "ISRC002", "Song B", "Artist")) {
		t.Error("different ISRC should not be duplicate")
	}
}

func TestDeduperByTitle(t *testing.T) {
	d := NewDeduper()

	if d.IsDuplicate(makeTrack("1", "", "Song A", "Artist")) {
		t.Error("first title match should not be duplicate")
	}
	if !d.IsDuplicate(makeTrack("2", "", "Song A", "Artist")) {
		t.Error("same title+artist should be duplicate")
	}
	if d.IsDuplicate(makeTrack("3", "", "Song B", "Artist")) {
		t.Error("different title should not be duplicate")
	}
}

func TestDeduperReset(t *testing.T) {
	d := NewDeduper()

	d.IsDuplicate(makeTrack("1", "ISRC001", "Song A", "Artist"))
	d.Reset()

	if d.IsDuplicate(makeTrack("2", "ISRC001", "Song A", "Artist")) {
		t.Error("after reset, ISRC should not be duplicate")
	}
}

func TestDeduperCaseInsensitive(t *testing.T) {
	d := NewDeduper()

	d.IsDuplicate(makeTrack("1", "isrc001", "Song A", "Artist"))
	if !d.IsDuplicate(makeTrack("2", "ISRC001", "Song B", "Artist")) {
		t.Error("ISRC should be case-insensitive")
	}
}

func TestDeduperTitleNormalization(t *testing.T) {
	d := NewDeduper()

	d.IsDuplicate(makeTrack("1", "", "Song A!", "Artist"))
	if !d.IsDuplicate(makeTrack("2", "", "Song A", "Artist")) {
		t.Error("title normalization should strip punctuation")
	}
}

func TestDeduperEmptyISRC(t *testing.T) {
	d := NewDeduper()

	// Empty ISRC and same title should be duplicate (punctuation stripped)
	d.IsDuplicate(makeTrack("1", "", "Hello, World!", "Artist"))
	if !d.IsDuplicate(makeTrack("2", "", "Hello World", "Artist")) {
		t.Error("empty ISRC title match should be duplicate (after normalization)")
	}
}
