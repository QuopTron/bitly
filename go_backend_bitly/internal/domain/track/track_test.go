package track

import (
	"testing"
	"time"
)

func TestTrack_ZeroValues(t *testing.T) {
	var tr Track
	if tr.ID != "" {
		t.Errorf("expected empty ID, got %q", tr.ID)
	}
	if tr.Title != "" {
		t.Errorf("expected empty Title, got %q", tr.Title)
	}
	if tr.DurationMs != 0 {
		t.Errorf("expected DurationMs 0, got %d", tr.DurationMs)
	}
	if tr.Explicit {
		t.Error("expected Explicit false")
	}
	if tr.Metadata != nil {
		t.Error("expected nil Metadata")
	}
	if !tr.CreatedAt.IsZero() {
		t.Error("expected zero CreatedAt")
	}
}

func TestTrack_FieldAccess(t *testing.T) {
	now := time.Now()
	tr := Track{
		ID:              "tr_001",
		Title:           "Bohemian Rhapsody",
		NormalizedTitle: "bohemian rhapsody",
		ArtistID:        "ar_001",
		AlbumID:         "al_001",
		DurationMs:      354000,
		ISRC:            "GBUM71029604",
		TrackNumber:     1,
		DiscNumber:      1,
		Explicit:        false,
		Metadata:        map[string]interface{}{"genre": "rock"},
		CreatedAt:       now,
		UpdatedAt:       now,
	}

	if tr.ID != "tr_001" {
		t.Errorf("ID = %q, want %q", tr.ID, "tr_001")
	}
	if tr.Title != "Bohemian Rhapsody" {
		t.Errorf("Title = %q, want %q", tr.Title, "Bohemian Rhapsody")
	}
	if tr.ArtistID != "ar_001" {
		t.Errorf("ArtistID = %q, want %q", tr.ArtistID, "ar_001")
	}
	if tr.DurationMs != 354000 {
		t.Errorf("DurationMs = %d, want %d", tr.DurationMs, 354000)
	}
	if tr.ISRC != "GBUM71029604" {
		t.Errorf("ISRC = %q, want %q", tr.ISRC, "GBUM71029604")
	}
	if tr.TrackNumber != 1 {
		t.Errorf("TrackNumber = %d, want %d", tr.TrackNumber, 1)
	}
	if tr.Metadata["genre"] != "rock" {
		t.Errorf("Metadata[genre] = %v, want %v", tr.Metadata["genre"], "rock")
	}
}

func TestTrack_OptionalFieldsEmpty(t *testing.T) {
	tr := Track{
		ID:     "tr_002",
		Title:  "Minimal Track",
		ArtistID: "ar_002",
	}
	if tr.AlbumID != "" {
		t.Errorf("expected empty AlbumID, got %q", tr.AlbumID)
	}
	if tr.ISRC != "" {
		t.Errorf("expected empty ISRC, got %q", tr.ISRC)
	}
	if tr.TrackNumber != 0 {
		t.Errorf("expected TrackNumber 0, got %d", tr.TrackNumber)
	}
	if tr.DiscNumber != 0 {
		t.Errorf("expected DiscNumber 0, got %d", tr.DiscNumber)
	}
}

func TestTrackWithSources_Construction(t *testing.T) {
	tr := Track{ID: "tr_001", Title: "Test Track"}
	tws := TrackWithSources{
		Track: tr,
		Sources: []TrackSource{
			{Provider: "spotify", ProviderID: "123", Quality: "high", Format: "mp3", Available: true},
		},
	}

	if tws.ID != "tr_001" {
		t.Errorf("embedded ID = %q, want %q", tws.ID, "tr_001")
	}
	if tws.Title != "Test Track" {
		t.Errorf("embedded Title = %q, want %q", tws.Title, "Test Track")
	}
	if len(tws.Sources) != 1 {
		t.Fatalf("expected 1 source, got %d", len(tws.Sources))
	}
	if tws.Sources[0].Provider != "spotify" {
		t.Errorf("Source Provider = %q, want %q", tws.Sources[0].Provider, "spotify")
	}
}

func TestTrackWithSources_NoSources(t *testing.T) {
	tws := TrackWithSources{
		Track:   Track{ID: "tr_003"},
		Sources: []TrackSource{},
	}
	if tws.Sources == nil {
		t.Error("expected non-nil empty slice, got nil")
	}
	if len(tws.Sources) != 0 {
		t.Errorf("expected 0 sources, got %d", len(tws.Sources))
	}
}

func TestTrackSource_AllFields(t *testing.T) {
	ts := TrackSource{
		Provider:   "deezer",
		ProviderID: "456",
		URL:        "https://deezer.com/track/456",
		Quality:    "lossless",
		Format:     "flac",
		Available:  true,
	}

	if ts.Provider != "deezer" {
		t.Errorf("Provider = %q, want %q", ts.Provider, "deezer")
	}
	if ts.ProviderID != "456" {
		t.Errorf("ProviderID = %q, want %q", ts.ProviderID, "456")
	}
	if ts.URL != "https://deezer.com/track/456" {
		t.Errorf("URL = %q, want %q", ts.URL, "https://deezer.com/track/456")
	}
	if ts.Available != true {
		t.Error("expected Available true")
	}
}

func TestTrackSource_Defaults(t *testing.T) {
	var ts TrackSource
	if ts.Available {
		t.Error("expected Available false by default")
	}
	if ts.URL != "" {
		t.Errorf("expected empty URL, got %q", ts.URL)
	}
}

func TestNormalizeTitle(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"Bohemian Rhapsody", "bohemian rhapsody"},
		{"  Hello World  ", "hello world"},
		{"", ""},
		{"   ", ""},
		{"UPPERCASE", "uppercase"},
		{"MiXeD CaSe", "mixed case"},
	}

	for _, tc := range tests {
		got := normalizeTitle(tc.input)
		if got != tc.want {
			t.Errorf("normalizeTitle(%q) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

func TestGenerateTrackID(t *testing.T) {
	tr := Track{
		ArtistID: "ar_001",
		ISRC:     "GBUM71029604",
	}
	got := generateTrackID(tr)
	want := "ar_001-GBUM71029604"
	if got != want {
		t.Errorf("generateTrackID() = %q, want %q", got, want)
	}
}

func TestGenerateTrackID_EmptyISRC(t *testing.T) {
	tr := Track{
		ArtistID: "ar_002",
		ISRC:     "",
	}
	got := generateTrackID(tr)
	want := "ar_002-"
	if got != want {
		t.Errorf("generateTrackID() with empty ISRC = %q, want %q", got, want)
	}
}

func TestNewService(t *testing.T) {
	s := NewService(nil)
	if s == nil {
		t.Fatal("expected non-nil Service")
	}
	if s.repo != nil {
		t.Error("expected nil repo in Service")
	}
}

func TestNewRepository(t *testing.T) {
	r := NewRepository(nil)
	if r == nil {
		t.Fatal("expected non-nil Repository")
	}
	if r.db != nil {
		t.Error("expected nil db in Repository")
	}
}

func TestTrack_TimeFields(t *testing.T) {
	now := time.Now().Round(time.Microsecond)
	tr := Track{
		ID:        "tr_t1",
		CreatedAt: now,
		UpdatedAt: now,
	}
	if !tr.CreatedAt.Equal(now) {
		t.Errorf("CreatedAt = %v, want %v", tr.CreatedAt, now)
	}
	if !tr.UpdatedAt.Equal(now) {
		t.Errorf("UpdatedAt = %v, want %v", tr.UpdatedAt, now)
	}
}
