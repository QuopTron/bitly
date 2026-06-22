package userlibrary

import (
	"testing"
	"time"
)

func TestSourceAttribution_ZeroValues(t *testing.T) {
	var sa SourceAttribution
	if sa.Title != "" {
		t.Errorf("expected empty Title, got %q", sa.Title)
	}
	if sa.Artist != "" {
		t.Errorf("expected empty Artist, got %q", sa.Artist)
	}
	if sa.Year != "" {
		t.Errorf("expected empty Year, got %q", sa.Year)
	}
}

func TestSourceAttribution_FieldAccess(t *testing.T) {
	sa := SourceAttribution{
		Title:       "Bohemian Rhapsody",
		Artist:      "Queen",
		Album:       "A Night at the Opera",
		Duration:    "354",
		ISRC:        "GBUM71029604",
		Genre:       "Rock",
		Label:       "EMI",
		Year:        "1975",
		Cover:       "https://example.com/cover.jpg",
		Lyrics:      "Is this the real life?",
		AlbumArtist: "Queen",
		ReleaseDate: "1975-10-31",
	}

	if sa.Title != "Bohemian Rhapsody" {
		t.Errorf("Title = %q, want %q", sa.Title, "Bohemian Rhapsody")
	}
	if sa.Artist != "Queen" {
		t.Errorf("Artist = %q, want %q", sa.Artist, "Queen")
	}
	if sa.Album != "A Night at the Opera" {
		t.Errorf("Album = %q, want %q", sa.Album, "A Night at the Opera")
	}
	if sa.ISRC != "GBUM71029604" {
		t.Errorf("ISRC = %q, want %q", sa.ISRC, "GBUM71029604")
	}
	if sa.Genre != "Rock" {
		t.Errorf("Genre = %q, want %q", sa.Genre, "Rock")
	}
	if sa.Year != "1975" {
		t.Errorf("Year = %q, want %q", sa.Year, "1975")
	}
	if sa.ReleaseDate != "1975-10-31" {
		t.Errorf("ReleaseDate = %q, want %q", sa.ReleaseDate, "1975-10-31")
	}
}

func TestDownloadedFile_ZeroValues(t *testing.T) {
	var df DownloadedFile
	if df.Path != "" {
		t.Errorf("expected empty Path, got %q", df.Path)
	}
	if df.SizeBytes != 0 {
		t.Errorf("expected SizeBytes 0, got %d", df.SizeBytes)
	}
	if df.Quality != "" {
		t.Errorf("expected empty Quality, got %q", df.Quality)
	}
	if df.Source != "" {
		t.Errorf("expected empty Source, got %q", df.Source)
	}
}

func TestDownloadedFile_FieldAccess(t *testing.T) {
	df := DownloadedFile{
		Path:      "/music/queen/bohemian.flac",
		SizeBytes: 12345678,
		Quality:   "lossless",
		Format:    "flac",
		Source:    "deezer",
	}

	if df.Path != "/music/queen/bohemian.flac" {
		t.Errorf("Path = %q, want %q", df.Path, "/music/queen/bohemian.flac")
	}
	if df.SizeBytes != 12345678 {
		t.Errorf("SizeBytes = %d, want %d", df.SizeBytes, 12345678)
	}
	if df.Quality != "lossless" {
		t.Errorf("Quality = %q, want %q", df.Quality, "lossless")
	}
	if df.Format != "flac" {
		t.Errorf("Format = %q, want %q", df.Format, "flac")
	}
	if df.Source != "deezer" {
		t.Errorf("Source = %q, want %q", df.Source, "deezer")
	}
}

func TestLikedTrack_ZeroValues(t *testing.T) {
	var lt LikedTrack
	if lt.UserID != "" {
		t.Errorf("expected empty UserID, got %q", lt.UserID)
	}
	if lt.TrackID != "" {
		t.Errorf("expected empty TrackID, got %q", lt.TrackID)
	}
	if !lt.LikedAt.IsZero() {
		t.Error("expected zero LikedAt")
	}
}

func TestLikedTrack_FieldAccess(t *testing.T) {
	now := time.Now().Round(time.Microsecond)
	lt := LikedTrack{
		UserID:  "usr_001",
		TrackID: "tr_001",
		LikedAt: now,
		SourceAttribution: SourceAttribution{
			Title:  "Bohemian Rhapsody",
			Artist: "Queen",
		},
	}

	if lt.UserID != "usr_001" {
		t.Errorf("UserID = %q, want %q", lt.UserID, "usr_001")
	}
	if lt.TrackID != "tr_001" {
		t.Errorf("TrackID = %q, want %q", lt.TrackID, "tr_001")
	}
	if !lt.LikedAt.Equal(now) {
		t.Errorf("LikedAt = %v, want %v", lt.LikedAt, now)
	}
	if lt.SourceAttribution.Title != "Bohemian Rhapsody" {
		t.Errorf("SourceAttribution.Title = %q, want %q", lt.SourceAttribution.Title, "Bohemian Rhapsody")
	}
}

func TestDownloadedTrack_ZeroValues(t *testing.T) {
	var dt DownloadedTrack
	if dt.UserID != "" {
		t.Errorf("expected empty UserID, got %q", dt.UserID)
	}
	if dt.AudioFile.Path != "" {
		t.Errorf("expected empty AudioFile.Path, got %q", dt.AudioFile.Path)
	}
	if dt.LyricsFile != nil {
		t.Error("expected nil LyricsFile")
	}
	if dt.VideoFile != nil {
		t.Error("expected nil VideoFile")
	}
}

func TestDownloadedTrack_FieldAccess(t *testing.T) {
	now := time.Now().Round(time.Microsecond)
	dt := DownloadedTrack{
		UserID:         "usr_001",
		TrackID:        "tr_001",
		SourceProvider: "spotify",
		SourceTrackID:  "spotify_track_123",
		MetadataSources: SourceAttribution{
			Title:  "Bohemian Rhapsody",
			Artist: "Queen",
		},
		AudioFile: DownloadedFile{
			Path:      "/audio/bohemian.flac",
			SizeBytes: 5000000,
			Quality:   "lossless",
			Format:    "flac",
			Source:    "spotify",
		},
		CoverFile: DownloadedFile{
			Path:      "/covers/bohemian.jpg",
			SizeBytes: 50000,
			Quality:   "high",
			Format:    "jpg",
		},
		DownloadedAt: now,
	}

	if dt.UserID != "usr_001" {
		t.Errorf("UserID = %q, want %q", dt.UserID, "usr_001")
	}
	if dt.TrackID != "tr_001" {
		t.Errorf("TrackID = %q, want %q", dt.TrackID, "tr_001")
	}
	if dt.SourceProvider != "spotify" {
		t.Errorf("SourceProvider = %q, want %q", dt.SourceProvider, "spotify")
	}
	if dt.AudioFile.Quality != "lossless" {
		t.Errorf("AudioFile.Quality = %q, want %q", dt.AudioFile.Quality, "lossless")
	}
	if dt.CoverFile.Path != "/covers/bohemian.jpg" {
		t.Errorf("CoverFile.Path = %q, want %q", dt.CoverFile.Path, "/covers/bohemian.jpg")
	}
	if dt.LyricsFile != nil {
		t.Error("expected nil LyricsFile")
	}
}

func TestDownloadedTrack_OptionalPointers(t *testing.T) {
	dt := DownloadedTrack{
		UserID:  "usr_002",
		TrackID: "tr_002",
		AudioFile: DownloadedFile{Path: "/audio/track.mp3"},
		CoverFile: DownloadedFile{Path: "/cover/track.jpg"},
		LyricsFile: &DownloadedFile{
			Path:      "/lyrics/track.lrc",
			SizeBytes: 2000,
			Format:    "lrc",
		},
		VideoFile: &DownloadedFile{
			Path:      "/video/track.mp4",
			SizeBytes: 50000000,
			Format:    "mp4",
		},
	}

	if dt.LyricsFile == nil {
		t.Fatal("expected non-nil LyricsFile")
	}
	if dt.LyricsFile.Path != "/lyrics/track.lrc" {
		t.Errorf("LyricsFile.Path = %q, want %q", dt.LyricsFile.Path, "/lyrics/track.lrc")
	}
	if dt.VideoFile == nil {
		t.Fatal("expected non-nil VideoFile")
	}
	if dt.VideoFile.SizeBytes != 50000000 {
		t.Errorf("VideoFile.SizeBytes = %d, want %d", dt.VideoFile.SizeBytes, 50000000)
	}
}

func TestCollection_ZeroValues(t *testing.T) {
	var c Collection
	if c.ID != "" {
		t.Errorf("expected empty ID, got %q", c.ID)
	}
	if c.UserID != "" {
		t.Errorf("expected empty UserID, got %q", c.UserID)
	}
	if c.TrackCount != 0 {
		t.Errorf("expected TrackCount 0, got %d", c.TrackCount)
	}
	if !c.CreatedAt.IsZero() {
		t.Error("expected zero CreatedAt")
	}
}

func TestCollection_FieldAccess(t *testing.T) {
	now := time.Now().Round(time.Microsecond)
	c := Collection{
		ID:          "col_001",
		UserID:      "usr_001",
		Name:        "Chill Vibes",
		Description: "Relaxing tracks",
		CoverURL:    "https://example.com/cover.jpg",
		TrackCount:  15,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	if c.ID != "col_001" {
		t.Errorf("ID = %q, want %q", c.ID, "col_001")
	}
	if c.Name != "Chill Vibes" {
		t.Errorf("Name = %q, want %q", c.Name, "Chill Vibes")
	}
	if c.Description != "Relaxing tracks" {
		t.Errorf("Description = %q, want %q", c.Description, "Relaxing tracks")
	}
	if c.TrackCount != 15 {
		t.Errorf("TrackCount = %d, want %d", c.TrackCount, 15)
	}
}

func TestCollectionTrack_Defaults(t *testing.T) {
	var ct CollectionTrack
	if ct.CollectionID != "" {
		t.Errorf("expected empty CollectionID, got %q", ct.CollectionID)
	}
	if ct.TrackID != "" {
		t.Errorf("expected empty TrackID, got %q", ct.TrackID)
	}
	if ct.Position != 0 {
		t.Errorf("expected Position 0, got %d", ct.Position)
	}
	if !ct.AddedAt.IsZero() {
		t.Error("expected zero AddedAt")
	}
}

func TestCollectionTrack_FieldAccess(t *testing.T) {
	now := time.Now().Round(time.Microsecond)
	ct := CollectionTrack{
		CollectionID: "col_001",
		TrackID:      "tr_001",
		Position:     3,
		AddedAt:      now,
	}

	if ct.CollectionID != "col_001" {
		t.Errorf("CollectionID = %q, want %q", ct.CollectionID, "col_001")
	}
	if ct.TrackID != "tr_001" {
		t.Errorf("TrackID = %q, want %q", ct.TrackID, "tr_001")
	}
	if ct.Position != 3 {
		t.Errorf("Position = %d, want %d", ct.Position, 3)
	}
}

func TestPlayHistoryEntry_ZeroValues(t *testing.T) {
	var phe PlayHistoryEntry
	if phe.ID != 0 {
		t.Errorf("expected ID 0, got %d", phe.ID)
	}
	if phe.UserID != "" {
		t.Errorf("expected empty UserID, got %q", phe.UserID)
	}
	if phe.TrackID != "" {
		t.Errorf("expected empty TrackID, got %q", phe.TrackID)
	}
	if phe.DurationPlayedMs != 0 {
		t.Errorf("expected DurationPlayedMs 0, got %d", phe.DurationPlayedMs)
	}
	if phe.DurationTotalMs != 0 {
		t.Errorf("expected DurationTotalMs 0, got %d", phe.DurationTotalMs)
	}
	if !phe.PlayedAt.IsZero() {
		t.Error("expected zero PlayedAt")
	}
}

func TestPlayHistoryEntry_FieldAccess(t *testing.T) {
	now := time.Now().Round(time.Microsecond)
	phe := PlayHistoryEntry{
		ID:               42,
		UserID:           "usr_001",
		TrackID:          "tr_001",
		TrackName:        "Bohemian Rhapsody",
		ArtistName:       "Queen",
		PlayedAt:         now,
		DurationPlayedMs: 354000,
		DurationTotalMs:  354000,
		Source:           "spotify",
	}

	if phe.ID != 42 {
		t.Errorf("ID = %d, want %d", phe.ID, 42)
	}
	if phe.UserID != "usr_001" {
		t.Errorf("UserID = %q, want %q", phe.UserID, "usr_001")
	}
	if phe.TrackName != "Bohemian Rhapsody" {
		t.Errorf("TrackName = %q, want %q", phe.TrackName, "Bohemian Rhapsody")
	}
	if phe.ArtistName != "Queen" {
		t.Errorf("ArtistName = %q, want %q", phe.ArtistName, "Queen")
	}
	if phe.DurationPlayedMs != 354000 {
		t.Errorf("DurationPlayedMs = %d, want %d", phe.DurationPlayedMs, 354000)
	}
	if phe.DurationTotalMs != 354000 {
		t.Errorf("DurationTotalMs = %d, want %d", phe.DurationTotalMs, 354000)
	}
	if phe.Source != "spotify" {
		t.Errorf("Source = %q, want %q", phe.Source, "spotify")
	}
}

func TestNewCollectionService(t *testing.T) {
	s := NewCollectionService(nil)
	if s == nil {
		t.Fatal("expected non-nil CollectionService")
	}
	if s.db != nil {
		t.Error("expected nil db")
	}
}

func TestNewHistoryService(t *testing.T) {
	s := NewHistoryService(nil)
	if s == nil {
		t.Fatal("expected non-nil HistoryService")
	}
	if s.db != nil {
		t.Error("expected nil db")
	}
}

func TestNewLikedService(t *testing.T) {
	s := NewLikedService(nil)
	if s == nil {
		t.Fatal("expected non-nil LikedService")
	}
	if s.db != nil {
		t.Error("expected nil db")
	}
}

func TestNewDownloadedService(t *testing.T) {
	s := NewDownloadedService(nil)
	if s == nil {
		t.Fatal("expected non-nil DownloadedService")
	}
	if s.db != nil {
		t.Error("expected nil db")
	}
}

func TestCollection_OptionalFields(t *testing.T) {
	c := Collection{ID: "col_002", Name: "Minimal", UserID: "usr_002"}
	if c.Description != "" {
		t.Errorf("expected empty Description, got %q", c.Description)
	}
	if c.CoverURL != "" {
		t.Errorf("expected empty CoverURL, got %q", c.CoverURL)
	}
}

func TestPlayHistoryEntry_OptionalFields(t *testing.T) {
	phe := PlayHistoryEntry{
		ID:      1,
		UserID:  "usr_001",
		TrackID: "tr_001",
		Source:  "local",
	}
	if phe.TrackName != "" {
		t.Errorf("expected empty TrackName, got %q", phe.TrackName)
	}
	if phe.ArtistName != "" {
		t.Errorf("expected empty ArtistName, got %q", phe.ArtistName)
	}
}
