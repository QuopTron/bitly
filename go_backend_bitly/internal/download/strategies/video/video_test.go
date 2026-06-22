package video

import (
	"context"
	"strings"
	"testing"
	"time"
)

func TestNewStrategy(t *testing.T) {
	s := NewStrategy("/usr/bin/yt-dlp", 5*time.Minute)
	if s == nil {
		t.Fatal("expected non-nil Strategy")
	}
	if s.ytdlpPath != "/usr/bin/yt-dlp" {
		t.Errorf("ytdlpPath = %q", s.ytdlpPath)
	}
	if s.timeout != 5*time.Minute {
		t.Errorf("timeout = %v", s.timeout)
	}
}

func TestNewStrategy_DefaultTimeout(t *testing.T) {
	s := NewStrategy("/usr/bin/yt-dlp", 0)
	if s.timeout != 5*time.Minute {
		t.Errorf("expected default 5m timeout, got %v", s.timeout)
	}
}

func TestNewStrategy_EmptyPath(t *testing.T) {
	s := NewStrategy("", 5*time.Minute)
	if s == nil {
		t.Fatal("expected non-nil Strategy")
	}
}

func TestDownload_NoYtDlp(t *testing.T) {
	s := NewStrategy("", 5*time.Minute)
	_, err := s.Download(context.Background(), VideoRequest{
		TrackName: "Test Song",
		Artist:    "Test Artist",
		OutputDir: "/tmp",
	})
	if err == nil {
		t.Fatal("expected error when yt-dlp not configured")
	}
	if !strings.Contains(err.Error(), "yt-dlp not configured") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestDownload_CancelledContext(t *testing.T) {
	s := NewStrategy("/usr/bin/yt-dlp", 5*time.Minute)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := s.Download(ctx, VideoRequest{
		TrackName: "Test Song",
		Artist:    "Test Artist",
		OutputDir: "/tmp",
	})
	if err == nil {
		t.Fatal("expected error for cancelled context")
	}
}

func TestVideoRequest_Fields(t *testing.T) {
	req := VideoRequest{
		TrackName: "Bohemian Rhapsody",
		Artist:    "Queen",
		OutputDir: "/tmp/videos",
		Format:    "best[height<=720]",
	}
	if req.TrackName != "Bohemian Rhapsody" {
		t.Errorf("TrackName = %q", req.TrackName)
	}
	if req.Artist != "Queen" {
		t.Errorf("Artist = %q", req.Artist)
	}
	if req.OutputDir != "/tmp/videos" {
		t.Errorf("OutputDir = %q", req.OutputDir)
	}
}

func TestVideoResult_Fields(t *testing.T) {
	r := VideoResult{
		FilePath: "/tmp/videos/Q - S.mp4",
		Size:     1000000,
	}
	if r.FilePath != "/tmp/videos/Q - S.mp4" {
		t.Errorf("FilePath = %q", r.FilePath)
	}
	if r.Size != 1000000 {
		t.Errorf("Size = %d", r.Size)
	}
}

func TestVideoRequest_DefaultFormat(t *testing.T) {
	req := VideoRequest{
		TrackName: "Song",
		Artist:    "Artist",
		OutputDir: "/tmp",
	}
	if req.Format != "" {
		t.Error("expected empty Format")
	}
}

func TestVideoResult_DefaultSize(t *testing.T) {
	r := VideoResult{FilePath: "/tmp/song.mp4"}
	if r.Size != 0 {
		t.Errorf("Size = %d, want 0", r.Size)
	}
}
