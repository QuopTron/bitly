package lyrics

import (
	"strings"
	"testing"
)

// fakeProvider returns canned lyrics; it records whether the duration-aware
// path was used so tests can assert the client prefers it.
type fakeProvider struct {
	name         string
	miss         bool
	useDuration  *bool
	syncedOnly   bool
	durationSeen int
}

func (f *fakeProvider) Name() string { return f.name }

func (f *fakeProvider) FetchLyrics(trackName, artistName string) (*Lyrics, error) {
	return f.fetch(trackName, artistName, 0)
}

func (f *fakeProvider) FetchLyricsWithDuration(trackName, artistName string, durationMs int) (*Lyrics, error) {
	if f.useDuration != nil {
		*f.useDuration = true
	}
	f.durationSeen = durationMs
	return f.fetch(trackName, artistName, durationMs)
}

func (f *fakeProvider) fetch(trackName, artistName string, _ int) (*Lyrics, error) {
	if f.miss {
		return nil, nil
	}
	if f.syncedOnly {
		return &Lyrics{SyncedLyrics: "[00:01.00]hi"}, nil
	}
	return &Lyrics{PlainLyrics: "hello"}, nil
}

func TestGetLyrics_UsesDurationAwarePath(t *testing.T) {
	c := NewClient()
	// Drop built-ins: NewClient registers lrclib which would attempt a real
	// network call. Replace providers entirely for determinism.
	used := false
	added := &fakeProvider{name: "ext-apple-music", useDuration: &used}
	c.providers = []Provider{added}

	lyr, err := c.GetLyrics("Percuma", "Mahalini", 180_000)
	if err != nil {
		t.Fatalf("GetLyrics: %v", err)
	}
	if !used {
		t.Error("expected duration-aware FetchLyricsWithDuration to be used")
	}
	if added.durationSeen != 180_000 {
		t.Errorf("duration not forwarded: got %d", added.durationSeen)
	}
	if lyr.TrackName != "Percuma" || lyr.ArtistName != "Mahalini" {
		t.Errorf("track/artist not stamped: %+v", lyr)
	}
}

func TestGetLyrics_SyncedOnlyAccepted(t *testing.T) {
	c := NewClient()
	c.providers = []Provider{&fakeProvider{name: "synced-only", syncedOnly: true}}
	lyr, err := c.GetLyrics("X", "Y", 0)
	if err != nil {
		t.Fatalf("GetLyrics: %v", err)
	}
	if !strings.Contains(lyr.SyncedLyrics, "[00:01.00]") {
		t.Errorf("expected synced lyrics back, got %q", lyr.SyncedLyrics)
	}
}

func TestGetLyrics_MissFallsThroughToNextProvider(t *testing.T) {
	c := NewClient()
	c.providers = []Provider{
		&fakeProvider{name: "misser", miss: true},
		&fakeProvider{name: "hitter"},
	}
	lyr, err := c.GetLyrics("X", "Y", 0)
	if err != nil {
		t.Fatalf("GetLyrics: %v", err)
	}
	if lyr.PlainLyrics != "hello" {
		t.Errorf("expected fallback hit, got %+v", lyr)
	}
}

func TestGetLyrics_AllMiss(t *testing.T) {
	c := NewClient()
	c.providers = []Provider{&fakeProvider{name: "a", miss: true}}
	if _, err := c.GetLyrics("X", "Y", 0); err == nil {
		t.Fatal("expected error when every provider misses")
	}
}

func TestAddProvider(t *testing.T) {
	c := NewClient()
	before := len(c.providers)
	c.AddProvider(&fakeProvider{name: "extra"})
	if len(c.providers) != before+1 {
		t.Errorf("AddProvider failed: %d → %d", before, len(c.providers))
	}
}
