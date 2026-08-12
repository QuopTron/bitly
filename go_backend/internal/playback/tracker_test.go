package playback

import "testing"

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
