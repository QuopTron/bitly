package playback

import "testing"

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
	if q[1].Position != 1 {
		t.Errorf("expected position 1, got %d", q[1].Position)
	}
}

func TestQueue_RemoveInvalid(t *testing.T) {
	tr := NewTracker(100)
	if tr.RemoveFromQueue(0) {
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
