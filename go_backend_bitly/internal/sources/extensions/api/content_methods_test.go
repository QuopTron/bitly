package api

import "testing"

func TestHandleURL(t *testing.T) {
	c, extID := setupTestClient(t)
	r, err := c.HandleURL(extID, "https://example.com/track/1")
	if err != nil {
		t.Fatal(err)
	}
	if r == nil {
		t.Fatal("expected non-nil result")
	}
	if r.Type != "track" {
		t.Errorf("unexpected type: %s", r.Type)
	}
	if r.Track == nil {
		t.Fatal("expected track")
	}
	if r.Track.ID != "t1" {
		t.Errorf("expected id t1, got %s", r.Track.ID)
	}

	_, err = c.HandleURL(extID, "invalid")
	if err == nil {
		t.Error("expected error for null return")
	}

	_, err = c.HandleURL("unknown", "url")
	if err == nil {
		t.Error("expected error for unknown extension")
	}
}

func TestGetLyrics(t *testing.T) {
	c, extID := setupTestClient(t)
	r, err := c.GetLyrics(extID, "song", "artist", 200000)
	if err != nil {
		t.Fatal(err)
	}
	if r == nil {
		t.Fatal("expected non-nil result")
	}
	if len(r.Lines) != 1 {
		t.Errorf("expected 1 line, got %d", len(r.Lines))
	}
	if r.PlainLyrics != "hello" {
		t.Errorf("unexpected lyrics: %s", r.PlainLyrics)
	}

	r, err = c.GetLyrics(extID, "null", "artist", 200000)
	if err != nil {
		t.Fatal(err)
	}
	if r != nil {
		t.Error("expected nil result for null")
	}

	_, err = c.GetLyrics("unknown", "song", "artist", 200000)
	if err == nil {
		t.Error("expected error for unknown extension")
	}
}

func TestEnrichTrack(t *testing.T) {
	c, extID := setupTestClient(t)
	orig := &TrackMetadata{ID: "t1", Name: "Test"}
	r, err := c.EnrichTrack(extID, orig)
	if err != nil {
		t.Fatal(err)
	}
	if r == nil {
		t.Fatal("expected non-nil result")
	}
	if r.Genre != "Rock" {
		t.Errorf("expected genre Rock, got %s", r.Genre)
	}

	r, err = c.EnrichTrack("unknown", orig)
	if err != nil {
		t.Fatal(err)
	}
	if r == nil {
		t.Fatal("expected non-nil result on error")
	}
}
