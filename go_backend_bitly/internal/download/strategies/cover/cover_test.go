package cover

import (
	"context"
	"net/http"
	"strings"
	"testing"
)

func TestNewStrategy(t *testing.T) {
	s := NewStrategy(nil)
	if s == nil {
		t.Fatal("expected non-nil Strategy")
	}
	if s.client == nil {
		t.Error("expected non-nil HTTP client")
	}
}

func TestDownload_NoURL(t *testing.T) {
	s := NewStrategy(nil)
	_, err := s.Download(context.Background(), CoverRequest{})
	if err == nil {
		t.Fatal("expected error for empty URL")
	}
	if !strings.Contains(err.Error(), "no URL") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestDownload_CancelledContext(t *testing.T) {
	s := NewStrategy(nil)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := s.Download(ctx, CoverRequest{
		URL: "https://example.com/cover.jpg",
	})
	if err == nil {
		t.Fatal("expected error for cancelled context")
	}
}

func TestCoverRequest_Fields(t *testing.T) {
	req := CoverRequest{
		URL:        "https://example.com/cover.jpg",
		TrackID:    "track_123",
		CacheDir:   "/tmp/covers",
		TrackName:  "Test Song",
		ArtistName: "Test Artist",
	}
	if req.URL != "https://example.com/cover.jpg" {
		t.Errorf("URL = %q", req.URL)
	}
	if req.TrackID != "track_123" {
		t.Errorf("TrackID = %q", req.TrackID)
	}
	if req.CacheDir != "/tmp/covers" {
		t.Errorf("CacheDir = %q", req.CacheDir)
	}
}

func TestCoverResult_Fields(t *testing.T) {
	r := CoverResult{
		FilePath: "/tmp/covers/cover_abc.jpg",
		Size:     100000,
		MimeType: "image/jpeg",
	}
	if r.FilePath != "/tmp/covers/cover_abc.jpg" {
		t.Errorf("FilePath = %q", r.FilePath)
	}
	if r.Size != 100000 {
		t.Errorf("Size = %d", r.Size)
	}
	if r.MimeType != "image/jpeg" {
		t.Errorf("MimeType = %q", r.MimeType)
	}
}

func TestCoverResult_DefaultValues(t *testing.T) {
	r := CoverResult{}
	if r.FilePath != "" {
		t.Error("expected empty FilePath")
	}
	if r.Size != 0 {
		t.Errorf("Size = %d, want 0", r.Size)
	}
}

func TestNewStrategy_WithClient(t *testing.T) {
	s := NewStrategy(&http.Client{})
	if s == nil {
		t.Fatal("expected non-nil Strategy")
	}
}
