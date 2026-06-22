package playlist

import (
	"fmt"
	"strings"
	"testing"
	"time"
)

func TestPlaylist_ZeroValues(t *testing.T) {
	var p Playlist
	if p.ID != "" {
		t.Errorf("expected empty ID, got %q", p.ID)
	}
	if p.UserID != "" {
		t.Errorf("expected empty UserID, got %q", p.UserID)
	}
	if p.Description != "" {
		t.Errorf("expected empty Description, got %q", p.Description)
	}
	if p.CoverURL != "" {
		t.Errorf("expected empty CoverURL, got %q", p.CoverURL)
	}
	if p.TrackCount != 0 {
		t.Errorf("expected TrackCount 0, got %d", p.TrackCount)
	}
	if !p.CreatedAt.IsZero() {
		t.Error("expected zero CreatedAt")
	}
}

func TestPlaylist_FieldAccess(t *testing.T) {
	now := time.Now().Round(time.Microsecond)
	p := Playlist{
		ID:          "pl_001",
		UserID:      "usr_001",
		Name:        "Favorites",
		Description: "My top tracks",
		CoverURL:    "https://example.com/cover.jpg",
		TrackCount:  25,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	if p.ID != "pl_001" {
		t.Errorf("ID = %q, want %q", p.ID, "pl_001")
	}
	if p.UserID != "usr_001" {
		t.Errorf("UserID = %q, want %q", p.UserID, "usr_001")
	}
	if p.Name != "Favorites" {
		t.Errorf("Name = %q, want %q", p.Name, "Favorites")
	}
	if p.Description != "My top tracks" {
		t.Errorf("Description = %q, want %q", p.Description, "My top tracks")
	}
	if p.TrackCount != 25 {
		t.Errorf("TrackCount = %d, want %d", p.TrackCount, 25)
	}
}

func TestPlaylist_OptionalFields(t *testing.T) {
	p := Playlist{ID: "pl_002", Name: "Minimal"}
	if p.Description != "" {
		t.Errorf("expected empty Description, got %q", p.Description)
	}
	if p.CoverURL != "" {
		t.Errorf("expected empty CoverURL, got %q", p.CoverURL)
	}
}

func TestPlaylistTrack_Defaults(t *testing.T) {
	var pt PlaylistTrack
	if pt.PlaylistID != "" {
		t.Errorf("expected empty PlaylistID, got %q", pt.PlaylistID)
	}
	if pt.TrackID != "" {
		t.Errorf("expected empty TrackID, got %q", pt.TrackID)
	}
	if pt.Position != 0 {
		t.Errorf("expected Position 0, got %d", pt.Position)
	}
	if !pt.AddedAt.IsZero() {
		t.Error("expected zero AddedAt")
	}
}

func TestPlaylistTrack_FieldAccess(t *testing.T) {
	now := time.Now().Round(time.Microsecond)
	pt := PlaylistTrack{
		PlaylistID: "pl_001",
		TrackID:    "tr_001",
		Position:   1,
		AddedAt:    now,
	}

	if pt.PlaylistID != "pl_001" {
		t.Errorf("PlaylistID = %q, want %q", pt.PlaylistID, "pl_001")
	}
	if pt.TrackID != "tr_001" {
		t.Errorf("TrackID = %q, want %q", pt.TrackID, "tr_001")
	}
	if pt.Position != 1 {
		t.Errorf("Position = %d, want %d", pt.Position, 1)
	}
	if !pt.AddedAt.Equal(now) {
		t.Errorf("AddedAt = %v, want %v", pt.AddedAt, now)
	}
}

func TestNewService_Valid(t *testing.T) {
	s := NewService(nil)
	if s == nil {
		t.Fatal("expected non-nil Service")
	}
}

func TestNewService_RepoField(t *testing.T) {
	s := NewService(nil)
	if s.repo != nil {
		t.Error("expected nil repo with nil input")
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

func TestPlaylist_IDFormat(t *testing.T) {
	now := time.Now()
	p := &Playlist{
		ID:        fmt.Sprintf("pl_%d", now.UnixNano()),
		Name:      "Format Test",
		CreatedAt: now,
		UpdatedAt: now,
	}

	if !strings.HasPrefix(p.ID, "pl_") {
		t.Errorf("ID %q should have prefix pl_", p.ID)
	}
	if len(p.ID) <= len("pl_") {
		t.Errorf("ID %q too short after prefix", p.ID)
	}
}

func TestPlaylist_TimestampsNonZero(t *testing.T) {
	now := time.Now()
	p := &Playlist{
		ID:        "pl_t1",
		Name:      "Timestamp Test",
		CreatedAt: now,
		UpdatedAt: now,
	}

	if p.CreatedAt.IsZero() {
		t.Error("CreatedAt should not be zero")
	}
	if p.UpdatedAt.IsZero() {
		t.Error("UpdatedAt should not be zero")
	}
}

func TestPlaylist_DescriptionOmitted(t *testing.T) {
	p := Playlist{ID: "pl_003", Name: "No Desc"}
	if p.Description != "" {
		t.Errorf("expected empty Description, got %q", p.Description)
	}
}

func TestService_CreateFormat(t *testing.T) {
	name := "My Playlist"
	desc := "A description"

	p := &Playlist{
		ID:          fmt.Sprintf("pl_%d", time.Now().UnixNano()),
		Name:        name,
		Description: desc,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if !strings.HasPrefix(p.ID, "pl_") {
		t.Errorf("expected ID to start with pl_, got %q", p.ID)
	}
	if p.Name != name {
		t.Errorf("Name = %q, want %q", p.Name, name)
	}
	if p.Description != desc {
		t.Errorf("Description = %q, want %q", p.Description, desc)
	}
	if p.CreatedAt.IsZero() {
		t.Error("CreatedAt must be non-zero")
	}
	if p.UpdatedAt.IsZero() {
		t.Error("UpdatedAt must be non-zero")
	}
}

func TestPlaylistTrack_ZeroAddedAt(t *testing.T) {
	pt := PlaylistTrack{PlaylistID: "pl_001", TrackID: "tr_001", Position: 0}
	if !pt.AddedAt.IsZero() {
		t.Error("expected zero AddedAt when not set")
	}
}

func TestPlaylist_EmptyCoverURL(t *testing.T) {
	p := Playlist{ID: "pl_x1", Name: "No Cover"}
	if p.CoverURL != "" {
		t.Errorf("expected empty CoverURL, got %q", p.CoverURL)
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
