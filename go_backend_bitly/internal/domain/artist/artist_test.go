package artist

import (
	"database/sql"
	"testing"
)

func TestArtist_ZeroValues(t *testing.T) {
	var a Artist
	if a.ID != "" {
		t.Errorf("expected empty ID, got %q", a.ID)
	}
	if a.Name != "" {
		t.Errorf("expected empty Name, got %q", a.Name)
	}
	if a.NormalizedName != "" {
		t.Errorf("expected empty NormalizedName, got %q", a.NormalizedName)
	}
	if a.ImageURL != "" {
		t.Errorf("expected empty ImageURL, got %q", a.ImageURL)
	}
	if a.Metadata != nil {
		t.Error("expected nil Metadata")
	}
}

func TestArtist_FieldAccess(t *testing.T) {
	a := Artist{
		ID:             "ar_001",
		Name:           "Queen",
		NormalizedName: "queen",
		ImageURL:       "https://example.com/queen.jpg",
		Metadata:       map[string]interface{}{"genre": "rock"},
	}

	if a.ID != "ar_001" {
		t.Errorf("ID = %q, want %q", a.ID, "ar_001")
	}
	if a.Name != "Queen" {
		t.Errorf("Name = %q, want %q", a.Name, "Queen")
	}
	if a.NormalizedName != "queen" {
		t.Errorf("NormalizedName = %q, want %q", a.NormalizedName, "queen")
	}
	if a.ImageURL != "https://example.com/queen.jpg" {
		t.Errorf("ImageURL = %q, want %q", a.ImageURL, "https://example.com/queen.jpg")
	}
	if v, ok := a.Metadata["genre"]; !ok || v != "rock" {
		t.Errorf("Metadata[genre] = %v, want %v", v, "rock")
	}
}

func TestArtist_OptionalFields(t *testing.T) {
	a := Artist{ID: "ar_002", Name: "Solo Artist"}
	if a.ImageURL != "" {
		t.Errorf("expected empty ImageURL, got %q", a.ImageURL)
	}
	if a.NormalizedName != "" {
		t.Errorf("expected empty NormalizedName, got %q", a.NormalizedName)
	}
}

func TestNewRepository_Valid(t *testing.T) {
	r := NewRepository(nil)
	if r == nil {
		t.Fatal("expected non-nil Repository")
	}
}

func TestNewRepository_NilDB(t *testing.T) {
	r := NewRepository(nil)
	if r.db != nil {
		t.Error("expected nil db field")
	}
}

func TestNewRepository_NoPanic(t *testing.T) {
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

func TestNewService_Valid(t *testing.T) {
	s := NewService(nil)
	if s == nil {
		t.Fatal("expected non-nil Service")
	}
}

func TestNewService_NilRepo(t *testing.T) {
	s := NewService(nil)
	if s.repo != nil {
		t.Error("expected nil repo field")
	}
}

func TestNormalizeName(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"Queen", "queen"},
		{"  The Beatles  ", "the beatles"},
		{"", ""},
		{"   ", ""},
		{"AC/DC", "ac/dc"},
		{"MÖTLEY CRÜE", "mötley crüe"},
		{"  spaced  out  ", "spaced  out"},
	}

	for _, tc := range tests {
		got := normalizeName(tc.input)
		if got != tc.want {
			t.Errorf("normalizeName(%q) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

func TestArtist_MetadataNilByDefault(t *testing.T) {
	a := Artist{ID: "ar_003", Name: "No Metadata"}
	if a.Metadata != nil {
		t.Error("expected nil Metadata for zero-value Artist")
	}
}

func TestArtist_MetadataAssignment(t *testing.T) {
	a := Artist{
		ID:       "ar_004",
		Name:     "Metadata Artist",
		Metadata: map[string]interface{}{"formed": 1994, "origin": "USA"},
	}
	if len(a.Metadata) != 2 {
		t.Errorf("expected 2 metadata entries, got %d", len(a.Metadata))
	}
	if a.Metadata["formed"] != 1994 {
		t.Errorf("Metadata[formed] = %v, want %v", a.Metadata["formed"], 1994)
	}
}
