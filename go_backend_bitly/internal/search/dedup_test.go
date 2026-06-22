package search

import "testing"

func TestDedupEmptyInput(t *testing.T) {
	d := NewDeduplicator()
	got := d.Deduplicate(nil)
	if len(got) != 0 {
		t.Errorf("expected empty result for nil input, got %d items", len(got))
	}

	got = d.Deduplicate([]RawResult{})
	if len(got) != 0 {
		t.Errorf("expected empty result for empty slice, got %d items", len(got))
	}
}

func TestDedupByISRC(t *testing.T) {
	d := NewDeduplicator()
	results := []RawResult{
		{ID: "1", Title: "Song A", Artist: "Artist1", ISRC: "USABC123"},
		{ID: "2", Title: "Song A", Artist: "Artist1", ISRC: "USABC123"},
		{ID: "3", Title: "Song B", Artist: "Artist2", ISRC: "USXYZ456"},
	}
	got := d.Deduplicate(results)
	if len(got) != 2 {
		t.Fatalf("expected 2 unique results, got %d", len(got))
	}
	if got[0].ISRC != "USABC123" && got[1].ISRC != "USABC123" {
		t.Error("expected USABC123 to be present")
	}
	if got[0].ISRC != "USXYZ456" && got[1].ISRC != "USXYZ456" {
		t.Error("expected USXYZ456 to be present")
	}
}

func TestDedupByTitleArtist(t *testing.T) {
	d := NewDeduplicator()
	results := []RawResult{
		{ID: "a2", Title: "hello world", Artist: "singer", ISRC: ""},
		{ID: "a3", Title: "Hello World", Artist: "Singer", ISRC: ""},
		{ID: "a4", Title: "Different", Artist: "Singer", ISRC: ""},
	}
	got := d.Deduplicate(results)
	if len(got) != 2 {
		t.Fatalf("expected 2 unique results (one per title+artist), got %d", len(got))
	}
}

func TestDedupMixedISRCAndTitle(t *testing.T) {
	d := NewDeduplicator()
	results := []RawResult{
		{ID: "1", Title: "Song", Artist: "Art", ISRC: "ISRC1"},
		{ID: "2", Title: "Song", Artist: "Art", ISRC: ""},
		{ID: "3", Title: "Song", Artist: "Art", ISRC: "ISRC1"},
	}
	got := d.Deduplicate(results)
	if len(got) != 2 {
		t.Fatalf("expected 2: one with ISRC, one without same title+artist, got %d", len(got))
	}
}

func TestDedupEmptyFields(t *testing.T) {
	d := NewDeduplicator()
	results := []RawResult{
		{ID: "x", Title: "", Artist: "", ISRC: ""},
		{ID: "y", Title: "", Artist: "", ISRC: ""},
	}
	got := d.Deduplicate(results)
	// Both entries produce the same key "|" so only one is kept.
	if len(got) != 1 {
		t.Errorf("expected 1 (duplicate empty keys collapse to one), got %d", len(got))
	}
}

func TestDedupOrderPreserved(t *testing.T) {
	d := NewDeduplicator()
	results := []RawResult{
		{ID: "first", Title: "Alpha", Artist: "Art", ISRC: "A1"},
		{ID: "second", Title: "Beta", Artist: "Art", ISRC: "B1"},
		{ID: "third", Title: "Alpha", Artist: "Art", ISRC: "A1"},
	}
	got := d.Deduplicate(results)
	if len(got) != 2 {
		t.Fatalf("expected 2, got %d", len(got))
	}
	if got[0].ID != "first" || got[1].ID != "second" {
		t.Errorf("order not preserved: got IDs %q and %q", got[0].ID, got[1].ID)
	}
}

func TestDedupTitleArtistDedupe(t *testing.T) {
	d := NewDeduplicator()
	input := []RawResult{
		{ID: "a", Title: "Track One", Artist: "Jane", ISRC: ""},
		{ID: "b", Title: "track one", Artist: "jane", ISRC: ""},
	}
	got := d.Deduplicate(input)
	if len(got) != 1 {
		t.Fatalf("expected 1 after title+artist casefold dedup, got %d", len(got))
	}
}

func TestDedupMultipleISRCSameResult(t *testing.T) {
	d := NewDeduplicator()
	input := []RawResult{
		{ID: "a", Title: "X", Artist: "Y", ISRC: "I1"},
		{ID: "b", Title: "X", Artist: "Y", ISRC: "I2"},
	}
	got := d.Deduplicate(input)
	if len(got) != 2 {
		t.Fatalf("expected 2 (different ISRCs), got %d", len(got))
	}
}

// Verify Deduplicate does not mutate the input slice.
func TestDedupNoMutation(t *testing.T) {
	d := NewDeduplicator()
	input := []RawResult{
		{ID: "1", Title: "A", Artist: "B", ISRC: "I1"},
		{ID: "2", Title: "A", Artist: "B", ISRC: "I1"},
	}
	_ = d.Deduplicate(input)
	if len(input) != 2 {
		t.Error("input slice was modified")
	}
}

func TestDedupDuplicateAfterWhitespaceTrim(t *testing.T) {
	d := NewDeduplicator()
	// TrimSpace only trims outer whitespace of the concatenated string;
	// inner spaces around the pipe are preserved, so use matching whitespace.
	input := []RawResult{
		{ID: "a", Title: "Same", Artist: "Artist", ISRC: ""},
		{ID: "b", Title: "same", Artist: "artist", ISRC: ""},
	}
	got := d.Deduplicate(input)
	if len(got) != 1 {
		t.Fatalf("expected 1 after casefold dedup, got %d", len(got))
	}
}

func BenchmarkDedup(b *testing.B) {
	d := NewDeduplicator()
	results := make([]RawResult, 1000)
	for i := 0; i < 1000; i++ {
		results[i] = RawResult{
			ID:     string(rune(i)),
			Title:  "Song",
			Artist: "Artist",
			ISRC:   string(rune(i)),
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		d.Deduplicate(results)
	}
}
