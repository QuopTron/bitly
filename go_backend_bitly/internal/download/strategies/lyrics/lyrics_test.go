package lyrics

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestNewStrategy(t *testing.T) {
	s := NewStrategy()
	if s == nil {
		t.Fatal("expected non-nil Strategy")
	}
}

func TestSaveLyrics_EmptyText(t *testing.T) {
	s := NewStrategy()
	_, err := s.SaveLyrics(context.Background(), LyricsRequest{}, "")
	if err == nil {
		t.Fatal("expected error for empty lyrics")
	}
	if !strings.Contains(err.Error(), "no lyrics") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestSavePlainLyrics_EmptyText(t *testing.T) {
	s := NewStrategy()
	_, err := s.SavePlainLyrics(context.Background(), LyricsRequest{}, "")
	if err == nil {
		t.Fatal("expected error for empty lyrics")
	}
}

func TestSaveLyrics_DetectsLRCFomat(t *testing.T) {
	dir := t.TempDir()
	s := NewStrategy()
	req := LyricsRequest{
		TrackName:  "Test Song",
		ArtistName: "Test Artist",
		OutputDir:  dir,
	}

	result, err := s.SaveLyrics(context.Background(), req, "[00:01.00]Hello\n[00:02.00]World")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result.Format != "lrc" {
		t.Errorf("Format = %q, want %q", result.Format, "lrc")
	}
	if !strings.HasSuffix(result.FilePath, ".lrc") {
		t.Errorf("expected .lrc extension, got %q", result.FilePath)
	}
	if _, err := os.Stat(result.FilePath); os.IsNotExist(err) {
		t.Error("expected file to exist")
	}
}

func TestSavePlainLyrics_CreatesTxtFile(t *testing.T) {
	dir := t.TempDir()
	s := NewStrategy()
	req := LyricsRequest{
		TrackName:  "Test Song",
		ArtistName: "Test Artist",
		OutputDir:  dir,
	}

	result, err := s.SavePlainLyrics(context.Background(), req, "Line one\nLine two")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result.Format != "txt" {
		t.Errorf("Format = %q, want %q", result.Format, "txt")
	}
	if !strings.HasSuffix(result.FilePath, ".txt") {
		t.Errorf("expected .txt extension, got %q", result.FilePath)
	}
	data, err := os.ReadFile(result.FilePath)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "Line one\nLine two" {
		t.Errorf("content = %q", string(data))
	}
}

func TestSaveLyrics_WithTrackID(t *testing.T) {
	dir := t.TempDir()
	s := NewStrategy()
	req := LyricsRequest{
		TrackID:    "track_123",
		TrackName:  "Test Song",
		ArtistName: "Test Artist",
		OutputDir:  dir,
	}

	result, err := s.SaveLyrics(context.Background(), req, "Some lyrics")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// With TrackID, filename should be hash-based (lyrics_<hash>.ext)
	if !strings.Contains(result.FilePath, "lyrics_") {
		t.Errorf("expected lyrics_ prefix in filename, got %q", result.FilePath)
	}
	if !strings.HasSuffix(result.FilePath, ".txt") && !strings.HasSuffix(result.FilePath, ".lrc") {
		t.Errorf("expected .txt or .lrc extension, got %q", result.FilePath)
	}
	// Verify file was created
	if _, err := os.Stat(result.FilePath); os.IsNotExist(err) {
		t.Error("expected file to exist on disk")
	}
}

func TestDetectLyricsFormat(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"[00:01.50]Hello", "lrc"},
		{"[01:30.00]World\n[02:00.00]Test", "lrc"},
		{"[0:05.00]Short minute", "lrc"},
		{"Plain text lyrics", "txt"},
		{"Line one\nLine two", "txt"},
		{"", "txt"},
		{"   ", "txt"},
	}
	for _, tt := range tests {
		got := detectLyricsFormat(tt.input)
		if got != tt.want {
			t.Errorf("detectLyricsFormat(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestSaveLyrics_CreatesDir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "nested", "dir")
	s := NewStrategy()
	req := LyricsRequest{
		TrackName:  "Song",
		ArtistName: "Artist",
		OutputDir:  dir,
	}

	result, err := s.SaveLyrics(context.Background(), req, "[00:01.00]test")
	if err != nil {
		t.Fatalf("expected directory creation: %v", err)
	}
	if _, err := os.Stat(result.FilePath); os.IsNotExist(err) {
		t.Error("expected file to exist in nested dir")
	}
}

func TestLyricsRequest_Fields(t *testing.T) {
	req := LyricsRequest{
		TrackID:    "track_123",
		TrackName:  "Song",
		ArtistName: "Artist",
		OutputDir:  "/tmp/lyrics",
	}
	if req.TrackID != "track_123" {
		t.Errorf("TrackID = %q", req.TrackID)
	}
	if req.TrackName != "Song" {
		t.Errorf("TrackName = %q", req.TrackName)
	}
}

func TestLyricsResult_Fields(t *testing.T) {
	r := LyricsResult{
		FilePath: "/tmp/lyrics/song.lrc",
		Format:   "lrc",
	}
	if r.FilePath != "/tmp/lyrics/song.lrc" {
		t.Errorf("FilePath = %q", r.FilePath)
	}
	if r.Format != "lrc" {
		t.Errorf("Format = %q", r.Format)
	}
}
