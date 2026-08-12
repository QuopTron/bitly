package playback

import "testing"

func TestHistory_Limit(t *testing.T) {
	tr := NewTracker(10)
	for i := 0; i < 20; i++ {
		tr.MarkPlayed(&TrackInfo{ID: "t", Title: "S"}, 60)
	}
	hist := tr.GetHistory(100)
	if len(hist) > 10 {
		t.Errorf("expected history capped at 10, got %d", len(hist))
	}
}

func TestHistory_NewestFirst(t *testing.T) {
	tr := NewTracker(100)
	for i := 0; i < 3; i++ {
		tr.MarkPlayed(&TrackInfo{ID: string(rune('0' + i)), Title: "S"}, 60)
	}
	hist := tr.GetHistory(10)
	if len(hist) < 3 {
		t.Fatal("expected at least 3 history entries")
	}
	id2 := string([]byte{'2'})
	id0 := string([]byte{'0'})
	if hist[0].Track.ID != id2 {
		t.Errorf("expected newest first, got %s at position 0", hist[0].Track.ID)
	}
	if hist[2].Track.ID != id0 {
		t.Errorf("expected oldest last, got %s at position 2", hist[2].Track.ID)
	}
}

func TestTopTracks(t *testing.T) {
	tr := NewTracker(100)
	tr.MarkPlayed(&TrackInfo{ID: "1", Title: "A"}, 60)
	tr.MarkPlayed(&TrackInfo{ID: "1", Title: "A"}, 60)
	tr.MarkPlayed(&TrackInfo{ID: "2", Title: "B"}, 60)

	top := tr.TopTracks(5)
	if len(top) != 2 {
		t.Fatalf("expected 2 top tracks, got %d", len(top))
	}
	if top[0] != "1" {
		t.Errorf("expected track 1 first, got %s", top[0])
	}
}

func TestTopArtists(t *testing.T) {
	tr := NewTracker(100)
	tr.MarkPlayed(&TrackInfo{ID: "1", Title: "A", ArtistID: "art1"}, 60)
	tr.MarkPlayed(&TrackInfo{ID: "2", Title: "B", ArtistID: "art1"}, 60)
	tr.MarkPlayed(&TrackInfo{ID: "3", Title: "C", ArtistID: "art2"}, 60)

	top := tr.TopArtists(5)
	if len(top) != 2 {
		t.Fatalf("expected 2 top artists, got %d", len(top))
	}
	if top[0] != "art1" {
		t.Errorf("expected art1 first (2 plays), got %s", top[0])
	}
}

func TestStats(t *testing.T) {
	tr := NewTracker(100)
	tr.MarkPlayed(&TrackInfo{ID: "1", Title: "A", Artist: "X", ArtistID: "x1"}, 120)
	tr.MarkPlayed(&TrackInfo{ID: "2", Title: "B", Artist: "Y", ArtistID: "y1"}, 240)

	stats := tr.Stats()
	if stats["totalPlays"].(int) != 2 {
		t.Errorf("expected 2 plays, got %d", stats["totalPlays"])
	}
	if stats["uniqueArtists"].(int) != 2 {
		t.Errorf("expected 2 artists, got %d", stats["uniqueArtists"])
	}
	if stats["totalDuration"].(int) != 360 {
		t.Errorf("expected 360s duration, got %d", stats["totalDuration"])
	}
}

func TestGetRecommendations_Empty(t *testing.T) {
	tr := NewTracker(100)
	recs := tr.GetRecommendations(10)
	if len(recs) != 0 {
		t.Errorf("expected empty recommendations, got %d", len(recs))
	}
}

func TestGetRecommendations_Dedup(t *testing.T) {
	tr := NewTracker(100)
	tr.MarkPlayed(&TrackInfo{ID: "1", Title: "A", Artist: "X"}, 60)
	tr.MarkPlayed(&TrackInfo{ID: "1", Title: "A", Artist: "X"}, 60)

	recs := tr.GetRecommendations(10)
	if len(recs) != 1 {
		t.Errorf("expected 1 unique recommendation, got %d", len(recs))
	}
}
