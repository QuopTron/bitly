package playback

import (
	"testing"
)

func TestNewTracker(t *testing.T) {
	tr := NewTracker(100)
	if tr == nil {
		t.Fatal("expected non-nil tracker")
	}
	if tr.maxHistory != 100 {
		t.Errorf("expected maxHistory 100, got %d", tr.maxHistory)
	}
}

func TestNewTracker_DefaultMaxHistory(t *testing.T) {
	tr := NewTracker(0)
	if tr.maxHistory != 200 {
		t.Errorf("expected default maxHistory 200, got %d", tr.maxHistory)
	}
}

func TestNowPlaying_InitiallyNil(t *testing.T) {
	tr := NewTracker(100)
	if tr.NowPlaying() != nil {
		t.Error("expected nil now playing initially")
	}
}

func TestSetNowPlaying(t *testing.T) {
	tr := NewTracker(100)
	track := &TrackInfo{ID: "123", Title: "Test", Artist: "Artist", DurationMs: 200000}
	tr.SetNowPlaying(track)
	np := tr.NowPlaying()
	if np == nil {
		t.Fatal("expected non-nil now playing")
	}
	if np.ID != "123" || np.Title != "Test" {
		t.Errorf("got %+v, expected ID=123 Title=Test", np)
	}
}

func TestMarkPlayed_AddsToHistory(t *testing.T) {
	tr := NewTracker(100)
	track := &TrackInfo{ID: "1", Title: "Song", Artist: "Artist", DurationMs: 180000}
	tr.MarkPlayed(track, 120)

	hist := tr.GetHistory(10)
	if len(hist) != 1 {
		t.Fatalf("expected 1 history entry, got %d", len(hist))
	}
	if hist[0].Track.ID != "1" {
		t.Errorf("expected track ID 1, got %s", hist[0].Track.ID)
	}
}

func TestMarkPlayed_ClearsNowPlaying(t *testing.T) {
	tr := NewTracker(100)
	track := &TrackInfo{ID: "1", Title: "Song", Artist: "Artist", DurationMs: 180000}
	tr.SetNowPlaying(track)
	tr.MarkPlayed(track, 120)
	if tr.NowPlaying() != nil {
		t.Error("expected now playing to be cleared after MarkPlayed")
	}
}

func TestPlayCount(t *testing.T) {
	tr := NewTracker(100)
	track := &TrackInfo{ID: "1", Title: "Song", Artist: "Artist"}
	tr.MarkPlayed(track, 60)
	tr.MarkPlayed(track, 90)
	if count := tr.PlayCount("1"); count != 2 {
		t.Errorf("expected play count 2, got %d", count)
	}
}

func TestQueue_AddAndGet(t *testing.T) {
	tr := NewTracker(100)
	track := &TrackInfo{ID: "1", Title: "Song", Artist: "A"}
	tr.AddToQueue(track, "user")
	q := tr.Queue()
	if len(q) != 1 {
		t.Fatalf("expected 1 queue item, got %d", len(q))
	}
	if q[0].Track.ID != "1" {
		t.Errorf("expected track ID 1, got %s", q[0].Track.ID)
	}
}

func TestQueue_Remove(t *testing.T) {
	tr := NewTracker(100)
	tr.AddToQueue(&TrackInfo{ID: "1", Title: "A"}, "user")
	tr.AddToQueue(&TrackInfo{ID: "2", Title: "B"}, "user")
	tr.AddToQueue(&TrackInfo{ID: "3", Title: "C"}, "user")

	if !tr.RemoveFromQueue(1) {
		t.Fatal("expected RemoveFromQueue to succeed")
	}
	q := tr.Queue()
	if len(q) != 2 {
		t.Fatalf("expected 2 items after remove, got %d", len(q))
	}
	if q[0].Track.ID != "1" || q[1].Track.ID != "3" {
		t.Errorf("after remove: got %+v", q)
	}
	// Check positions updated
	if q[1].Position != 1 {
		t.Errorf("expected position 1, got %d", q[1].Position)
	}
}

func TestQueue_RemoveInvalid(t *testing.T) {
	tr := NewTracker(100)
	if tr.RemoveFromQueue(0) { // empty queue
		t.Error("expected false for empty queue")
	}
	if tr.RemoveFromQueue(-1) {
		t.Error("expected false for negative position")
	}
}

func TestQueue_Clear(t *testing.T) {
	tr := NewTracker(100)
	tr.AddToQueue(&TrackInfo{ID: "1", Title: "A"}, "user")
	tr.ClearQueue()
	if len(tr.Queue()) != 0 {
		t.Error("expected empty queue after clear")
	}
}

func TestQueue_Reorder(t *testing.T) {
	tr := NewTracker(100)
	tr.AddToQueue(&TrackInfo{ID: "1", Title: "A"}, "user")
	tr.AddToQueue(&TrackInfo{ID: "2", Title: "B"}, "user")
	tr.AddToQueue(&TrackInfo{ID: "3", Title: "C"}, "user")

	if !tr.ReorderQueue(0, 2) {
		t.Fatal("expected ReorderQueue to succeed")
	}
	q := tr.Queue()
	if q[2].Track.ID != "1" {
		t.Errorf("expected track 1 at position 2, got %s", q[2].Track.ID)
	}
}

func TestQueue_ReorderInvalid(t *testing.T) {
	tr := NewTracker(100)
	if tr.ReorderQueue(0, 1) {
		t.Error("expected false for empty queue")
	}
}

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
	// Should be newest first: last added = index 0
	id2 := string([]byte{'2'})
	id0 := string([]byte{'0'})
	if hist[0].Track.ID != id2 {
		t.Errorf("expected newest first, got %s at position 0", hist[0].Track.ID)
	}
	if hist[2].Track.ID != id0 {
		t.Errorf("expected oldest last, got %s at position 2", hist[2].Track.ID)
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

func TestTopTracks(t *testing.T) {
	tr := NewTracker(100)
	tr.MarkPlayed(&TrackInfo{ID: "1", Title: "A"}, 60)
	tr.MarkPlayed(&TrackInfo{ID: "1", Title: "A"}, 60) // twice
	tr.MarkPlayed(&TrackInfo{ID: "2", Title: "B"}, 60) // once

	top := tr.TopTracks(5)
	if len(top) != 2 {
		t.Fatalf("expected 2 top tracks, got %d", len(top))
	}
	if top[0] != "1" {
		t.Errorf("expected track 1 first, got %s", top[0])
	}
}

func TestGetRecommendations_Empty(t *testing.T) {
	tr := NewTracker(100)
	recs := tr.GetRecommendations(10)
	if recs != nil && len(recs) != 0 {
		t.Errorf("expected empty recommendations, got %d", len(recs))
	}
}

func TestGetRecommendations_Dedup(t *testing.T) {
	tr := NewTracker(100)
	tr.MarkPlayed(&TrackInfo{ID: "1", Title: "A", Artist: "X"}, 60)
	tr.MarkPlayed(&TrackInfo{ID: "1", Title: "A", Artist: "X"}, 60) // duplicate

	recs := tr.GetRecommendations(10)
	if len(recs) != 1 {
		t.Errorf("expected 1 unique recommendation, got %d", len(recs))
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
