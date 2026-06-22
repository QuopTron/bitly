package search

import "testing"

func TestAggregatorEmptyInput(t *testing.T) {
	a := NewAggregator()
	got := a.Aggregate(nil)
	if len(got) != 0 {
		t.Errorf("expected empty for nil, got %d items", len(got))
	}
	got = a.Aggregate([]RawResult{})
	if len(got) != 0 {
		t.Errorf("expected empty for empty slice, got %d items", len(got))
	}
}

func TestAggregatorGroupsByISRC(t *testing.T) {
	a := NewAggregator()
	input := []RawResult{
		{ID: "s1", Title: "Song", Artist: "Artist", Album: "Album", Duration: 200000, ISRC: "I1", Source: "source_a"},
		{ID: "s2", Title: "Song", Artist: "Artist", Album: "Album", Duration: 200000, ISRC: "I1", Source: "source_b"},
		{ID: "s3", Title: "Other", Artist: "Other", Album: "Other Album", Duration: 150000, ISRC: "I2", Source: "source_a"},
	}
	got := a.Aggregate(input)
	if len(got) != 2 {
		t.Fatalf("expected 2 unified results, got %d", len(got))
	}

	var u1, u2 *UnifiedResult
	for i := range got {
		if got[i].ISRC == "I1" {
			u1 = &got[i]
		} else if got[i].ISRC == "I2" {
			u2 = &got[i]
		}
	}
	if u1 == nil {
		t.Fatal("expected unified result for I1")
	}
	if len(u1.Sources) != 2 {
		t.Errorf("expected 2 sources for I1, got %d", len(u1.Sources))
	}
	if u1.Sources["source_a"].Available != true || u1.Sources["source_b"].Available != true {
		t.Error("expected both sources to be available")
	}
	if u1.Title != "Song" || u1.Artist != "Artist" {
		t.Errorf("expected Title=Song Artist=Artist, got Title=%q Artist=%q", u1.Title, u1.Artist)
	}
	if u2 == nil {
		t.Fatal("expected unified result for I2")
	}
}

func TestAggregatorItemsWithoutISRC(t *testing.T) {
	a := NewAggregator()
	input := []RawResult{
		{ID: "a1", Title: "No ISRC 1", Artist: "A", Source: "source_a", Duration: 100},
		{ID: "a2", Title: "No ISRC 2", Artist: "B", Source: "source_b", Duration: 200},
	}
	got := a.Aggregate(input)
	if len(got) != 2 {
		t.Fatalf("expected 2 unified results (each without ISRC individually), got %d", len(got))
	}
	for _, u := range got {
		if len(u.Sources) != 1 {
			t.Errorf("expected 1 source per item, got %d for %s", len(u.Sources), u.ID)
		}
	}
}

func TestAggregatorMixedISRCAndNoISRC(t *testing.T) {
	a := NewAggregator()
	input := []RawResult{
		{ID: "w1", Title: "With ISRC", Artist: "X", ISRC: "IR1", Source: "a"},
		{ID: "w2", Title: "With ISRC", Artist: "X", ISRC: "IR1", Source: "b"},
		{ID: "w3", Title: "Without ISRC", Artist: "Y", ISRC: "", Source: "c"},
	}
	got := a.Aggregate(input)
	if len(got) != 2 {
		t.Fatalf("expected 2 (1 merged, 1 individual), got %d", len(got))
	}
}

func TestAggregatorFirstValuesUsed(t *testing.T) {
	a := NewAggregator()
	input := []RawResult{
		{ISRC: "M1", Title: "First Title", Artist: "First Artist", Album: "First Album", Duration: 1000, Source: "a"},
		{ISRC: "M1", Title: "Second Title", Artist: "Second Artist", Album: "Second Album", Duration: 2000, Source: "b"},
	}
	got := a.Aggregate(input)
	if len(got) != 1 {
		t.Fatalf("expected 1 merged result, got %d", len(got))
	}
	if got[0].Title != "First Title" {
		t.Errorf("expected first Title, got %q", got[0].Title)
	}
	if got[0].Artist != "First Artist" {
		t.Errorf("expected first Artist, got %q", got[0].Artist)
	}
	if got[0].Album != "First Album" {
		t.Errorf("expected first Album, got %q", got[0].Album)
	}
	if got[0].DurationMs != 1000 {
		t.Errorf("expected first DurationMs, got %d", got[0].DurationMs)
	}
}

func TestAggregatorSourcesMerged(t *testing.T) {
	a := NewAggregator()
	input := []RawResult{
		{ISRC: "X1", Title: "T", Artist: "A", Source: "spotify"},
		{ISRC: "X1", Title: "T", Artist: "A", Source: "apple"},
		{ISRC: "X1", Title: "T", Artist: "A", Source: "deezer"},
	}
	got := a.Aggregate(input)
	if len(got) != 1 {
		t.Fatalf("expected 1, got %d", len(got))
	}
	if len(got[0].Sources) != 3 {
		t.Errorf("expected 3 sources merged, got %d", len(got[0].Sources))
	}
	for _, name := range []string{"spotify", "apple", "deezer"} {
		if !got[0].Sources[name].Available {
			t.Errorf("source %s should be available", name)
		}
	}
}

func TestAggregatorNoISRCCopiesID(t *testing.T) {
	a := NewAggregator()
	input := []RawResult{
		{ID: "custom-id", Title: "T", Artist: "A", Source: "s"},
	}
	got := a.Aggregate(input)
	if len(got) != 1 {
		t.Fatalf("expected 1, got %d", len(got))
	}
	if got[0].ID != "custom-id" {
		t.Errorf("expected ID=custom-id, got %q", got[0].ID)
	}
}

func TestAggregatorAllDuplicateISRC(t *testing.T) {
	a := NewAggregator()
	input := make([]RawResult, 5)
	for i := 0; i < 5; i++ {
		input[i] = RawResult{
			ISRC: "SAME", Title: "T", Artist: "A", Source: string(rune('a' + i)),
		}
	}
	got := a.Aggregate(input)
	if len(got) != 1 {
		t.Fatalf("expected 1 merged result, got %d", len(got))
	}
	if len(got[0].Sources) != 5 {
		t.Errorf("expected 5 sources, got %d", len(got[0].Sources))
	}
}

func TestAggregatorNoISRCDuplicateIDsAsSeparate(t *testing.T) {
	a := NewAggregator()
	input := []RawResult{
		{ID: "dup", Title: "T1", Artist: "A1", ISRC: "", Source: "s"},
		{ID: "dup", Title: "T2", Artist: "A2", ISRC: "", Source: "s"},
	}
	got := a.Aggregate(input)
	if len(got) != 2 {
		t.Fatalf("expected 2 separate results for items without ISRC, got %d", len(got))
	}
}
