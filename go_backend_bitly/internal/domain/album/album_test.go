package album

import (
	"database/sql"
	"testing"
)

func TestAlbum_ZeroValues(t *testing.T) {
	var a Album
	if a.ID != "" {
		t.Errorf("expected empty ID, got %q", a.ID)
	}
	if a.Year != 0 {
		t.Errorf("expected Year 0, got %d", a.Year)
	}
	if a.CoverURL != "" {
		t.Errorf("expected empty CoverURL, got %q", a.CoverURL)
	}
	if a.TrackCount != 0 {
		t.Errorf("expected TrackCount 0, got %d", a.TrackCount)
	}
	if a.Metadata != nil {
		t.Error("expected nil Metadata")
	}
}

func TestAlbum_FieldAccess(t *testing.T) {
	a := Album{
		ID:         "al_001",
		Title:      "A Night at the Opera",
		ArtistID:   "ar_001",
		Year:       1975,
		CoverURL:   "https://example.com/cover.jpg",
		TrackCount: 12,
		Metadata:   map[string]interface{}{"genre": "rock"},
	}

	if a.ID != "al_001" {
		t.Errorf("ID = %q, want %q", a.ID, "al_001")
	}
	if a.Title != "A Night at the Opera" {
		t.Errorf("Title = %q, want %q", a.Title, "A Night at the Opera")
	}
	if a.ArtistID != "ar_001" {
		t.Errorf("ArtistID = %q, want %q", a.ArtistID, "ar_001")
	}
	if a.Year != 1975 {
		t.Errorf("Year = %d, want %d", a.Year, 1975)
	}
	if a.TrackCount != 12 {
		t.Errorf("TrackCount = %d, want %d", a.TrackCount, 12)
	}
	if v, ok := a.Metadata["genre"]; !ok || v != "rock" {
		t.Errorf("Metadata[genre] = %v, want %v", v, "rock")
	}
}

func TestAlbum_OptionalFields(t *testing.T) {
	a := Album{ID: "al_002", Title: "Minimal", ArtistID: "ar_002"}
	if a.CoverURL != "" {
		t.Errorf("expected empty CoverURL, got %q", a.CoverURL)
	}
	if a.Year != 0 {
		t.Errorf("expected Year 0, got %d", a.Year)
	}
}

func TestNewRepository_Valid(t *testing.T) {
	r := NewRepository(nil)
	if r == nil {
		t.Fatal("expected non-nil Repository")
	}
}

func TestNewRepository_Access(t *testing.T) {
	r := NewRepository(nil)
	if r.db != nil {
		t.Error("expected nil db field")
	}
}

func TestNewService_Valid(t *testing.T) {
	s := NewService(nil, nil)
	if s == nil {
		t.Fatal("expected non-nil Service")
	}
}

func TestNewService_Fields(t *testing.T) {
	s := NewService(nil, nil)
	if s.repo != nil {
		t.Error("expected nil repo")
	}
	if s.trackRepo != nil {
		t.Error("expected nil trackRepo")
	}
}

func TestAlbum_TrackCountZeroByDefault(t *testing.T) {
	a := Album{ID: "al_003", Title: "Tracks Unknown", ArtistID: "ar_003"}
	if a.TrackCount != 0 {
		t.Errorf("expected TrackCount 0, got %d", a.TrackCount)
	}
}

func TestAlbum_ToString(t *testing.T) {
	a := Album{ID: "al_004", Title: "The Dark Side of the Moon", ArtistID: "ar_004", Year: 1973}
	if a.Title != "The Dark Side of the Moon" {
		t.Errorf("Title = %q, want %q", a.Title, "The Dark Side of the Moon")
	}
	if a.Year != 1973 {
		t.Errorf("Year = %d, want %d", a.Year, 1973)
	}
}

func TestRepository_NilDBNotPanic(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("NewRepository with nil should not panic, got %v", r)
		}
	}()
	_ = NewRepository(nil)
}

func TestNewRepository_WithDB(t *testing.T) {
	db, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Skip("sqlite3 driver not available:", err)
	}
	defer db.Close()

	r := NewRepository(db)
	if r == nil {
		t.Fatal("expected non-nil Repository")
	}
	if r.db != db {
		t.Error("Repository.db does not match input *sql.DB")
	}
}
