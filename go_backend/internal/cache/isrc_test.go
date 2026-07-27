package cache

import (
	"testing"
)

func TestISRCIndexAddLookup(t *testing.T) {
	idx := NewISRCIndex()

	idx.Add("GBUM71029604", &TrackRef{TrackID: "track_123"})
	idx.Add("USUM71712345", &TrackRef{TrackID: "track_456"})

	ref, ok := idx.Lookup("GBUM71029604")
	if !ok || ref.TrackID != "track_123" {
		t.Errorf("expected track_123, got %v (ok=%v)", ref, ok)
	}

	ref, ok = idx.Lookup("USUM71712345")
	if !ok || ref.TrackID != "track_456" {
		t.Errorf("expected track_456, got %v (ok=%v)", ref, ok)
	}
}

func TestISRCIndexLookupMissing(t *testing.T) {
	idx := NewISRCIndex()

	_, ok := idx.Lookup("NONEXISTENT")
	if ok {
		t.Error("expected false for missing ISRC")
	}
}

func TestISRCIndexHas(t *testing.T) {
	idx := NewISRCIndex()
	idx.Add("GBUM71029604", &TrackRef{})

	if !idx.Has("GBUM71029604") {
		t.Error("Has should return true for existing ISRC")
	}
	if idx.Has("NONEXISTENT") {
		t.Error("Has should return false for missing ISRC")
	}
}

func TestISRCIndexRemove(t *testing.T) {
	idx := NewISRCIndex()
	idx.Add("GBUM71029604", &TrackRef{})
	idx.Remove("GBUM71029604")

	if idx.Has("GBUM71029604") {
		t.Error("expected false after remove")
	}
}

func TestISRCIndexOverwrite(t *testing.T) {
	idx := NewISRCIndex()
	idx.Add("GBUM71029604", &TrackRef{TrackID: "track_123"})
	idx.Add("GBUM71029604", &TrackRef{TrackID: "track_456"})

	ref, _ := idx.Lookup("GBUM71029604")
	if ref.TrackID != "track_456" {
		t.Errorf("expected track_456 after overwrite, got %s", ref.TrackID)
	}
}

func TestISRCIndexLen(t *testing.T) {
	idx := NewISRCIndex()
	if idx.Len() != 0 {
		t.Errorf("expected 0, got %d", idx.Len())
	}

	idx.Add("A", &TrackRef{})
	idx.Add("B", &TrackRef{})
	if idx.Len() != 2 {
		t.Errorf("expected 2, got %d", idx.Len())
	}
}

func TestISRCIndexClear(t *testing.T) {
	idx := NewISRCIndex()
	idx.Add("A", &TrackRef{})
	idx.Add("B", &TrackRef{})
	idx.Clear()

	if idx.Len() != 0 {
		t.Errorf("expected 0 after clear, got %d", idx.Len())
	}
}

func TestISRCIndexEmptyISRC(t *testing.T) {
	idx := NewISRCIndex()
	idx.Add("", &TrackRef{TrackID: "track"}) // should be no-op

	if idx.Len() != 0 {
		t.Errorf("expected 0 for empty ISRC add, got %d", idx.Len())
	}

	_, ok := idx.Lookup("")
	if ok {
		t.Error("Lookup of empty ISRC should return false")
	}

	if idx.Has("") {
		t.Error("Has of empty ISRC should return false")
	}
}
