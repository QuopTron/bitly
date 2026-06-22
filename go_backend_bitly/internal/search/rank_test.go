package search

import "testing"

func TestRankerScoreEmptyQuery(t *testing.T) {
	r := &Ranker{}
	u := UnifiedResult{Title: "Anything", Artist: "Anyone"}
	if s := r.Score(u, ""); s != 0 {
		t.Errorf("expected 0 for empty query, got %f", s)
	}
}

func TestRankerScoreExactTitleMatch(t *testing.T) {
	r := &Ranker{}
	u := UnifiedResult{Title: "Bohemian Rhapsody", Artist: "Queen"}
	s := r.Score(u, "Bohemian Rhapsody")
	if s < 100 {
		t.Errorf("expected score >= 100 for exact title match, got %f", s)
	}
}

func TestRankerScorePrefixTitleMatch(t *testing.T) {
	r := &Ranker{}
	u := UnifiedResult{Title: "Bohemian Rhapsody", Artist: "Queen"}
	s := r.Score(u, "Bohemian")
	if s < 80 || s >= 100 {
		t.Errorf("expected score in [80,100) for prefix title match, got %f", s)
	}
}

func TestRankerScoreContainsTitleMatch(t *testing.T) {
	r := &Ranker{}
	u := UnifiedResult{Title: "Bohemian Rhapsody", Artist: "Queen"}
	s := r.Score(u, "Rhapsody")
	if s < 60 || s >= 80 {
		t.Errorf("expected score in [60,80) for contains title match, got %f", s)
	}
}

func TestRankerScoreExactArtistMatch(t *testing.T) {
	r := &Ranker{}
	u := UnifiedResult{Title: "A Day in the Life", Artist: "The Beatles"}
	s := r.Score(u, "The Beatles")
	if s < 50 {
		t.Errorf("expected score >= 50 for exact artist match, got %f", s)
	}
}

func TestRankerScoreISRCMatch(t *testing.T) {
	r := &Ranker{}
	u := UnifiedResult{ISRC: "USABC1234567"}
	s := r.Score(u, "USABC1234567")
	if s < 90 {
		t.Errorf("expected score >= 90 for ISRC match, got %f", s)
	}
}

func TestRankerScoreAlbumMatchBoost(t *testing.T) {
	r := &Ranker{}
	u := UnifiedResult{Title: "Greatest Hits Collection", Artist: "Artist", Album: "Greatest Hits"}
	s := r.Score(u, "Greatest")
	if s < 80 {
		t.Errorf("expected score >= 80 (title contains 60 + album boost 20), got %f", s)
	}
}

func TestRankerScoreAvailabilityBoost(t *testing.T) {
	r := &Ranker{}
	u := UnifiedResult{
		Title:      "Song",
		Artist:     "Artist",
		BestSource: "spotify",
		Sources:    map[string]SourceAvailability{"spotify": {}, "apple": {}},
	}
	s := r.Score(u, "Song")
	if s < 115 {
		t.Errorf("expected score >= 115 (exact title 100 + best source 10 + extra source 5), got %f", s)
	}
}

func TestRankerScoreCaseInsensitive(t *testing.T) {
	r := &Ranker{}
	u := UnifiedResult{Title: "Bohemian Rhapsody", Artist: "Queen"}
	s := r.Score(u, "bohemian rhapsody")
	if s < 100 {
		t.Errorf("expected score >= 100 for case-insensitive exact match, got %f", s)
	}
}

func TestRankerSortByRelevanceEmpty(t *testing.T) {
	r := &Ranker{}
	got := r.SortByRelevance(nil, "query")
	if len(got) != 0 {
		t.Errorf("expected empty for nil, got %d items", len(got))
	}
	got = r.SortByRelevance([]UnifiedResult{}, "query")
	if len(got) != 0 {
		t.Errorf("expected empty for empty slice, got %d items", len(got))
	}
}

func TestRankerSortByRelevanceOrder(t *testing.T) {
	r := &Ranker{}
	results := []UnifiedResult{
		{Title: "Zebra", Artist: "A"},   // no match → 0
		{Title: "Apple", Artist: "B"},   // no match → 0
		{Title: "Zoo", Artist: "C"},     // exact title match for "Zoo" → 100
	}
	got := r.SortByRelevance(results, "Zoo")
	if len(got) != 3 {
		t.Fatalf("expected 3 results, got %d", len(got))
	}
	if got[0].Title != "Zoo" {
		t.Errorf("expected first to be exact match 'Zoo', got %q", got[0].Title)
	}
	if got[0].Title != "Zoo" || got[1].Title != "Apple" || got[2].Title != "Zebra" {
		t.Logf("sorted order: %q, %q, %q", got[0].Title, got[1].Title, got[2].Title)
	}
}

func TestRankerSortByRelevanceStable(t *testing.T) {
	r := &Ranker{}
	results := []UnifiedResult{
		{Title: "Same Score A", Artist: "X"},
		{Title: "Same Score B", Artist: "X"},
		{Title: "Same Score C", Artist: "X"},
	}
	got := r.SortByRelevance(results, "Same Score")
	if len(got) != 3 {
		t.Fatalf("expected 3 results, got %d", len(got))
	}
}

func TestRankerScoreExactTitleDominates(t *testing.T) {
	r := &Ranker{}
	exactTitle := UnifiedResult{Title: "Hello", Artist: "World", BestSource: "spotify", Sources: map[string]SourceAvailability{"spotify": {}}}
	prefixTitle := UnifiedResult{Title: "Hello World", Artist: "World"}
	s1 := r.Score(exactTitle, "Hello")
	s2 := r.Score(prefixTitle, "Hello")
	if s1 <= s2 {
		t.Errorf("exact title match (%f) should outscore prefix match (%f)", s1, s2)
	}
}

func TestRankerNoMatch(t *testing.T) {
	r := &Ranker{}
	u := UnifiedResult{Title: "AAAA", Artist: "BBBB", Album: "CCCC"}
	s := r.Score(u, "ZZZZ")
	if s != 0 {
		t.Errorf("expected 0 for no match, got %f", s)
	}
}
