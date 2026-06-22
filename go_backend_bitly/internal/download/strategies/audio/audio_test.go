package audio

import (
	"context"
	"strings"
	"testing"
)

func TestNewStrategy(t *testing.T) {
	s := NewStrategy(nil, 3)
	if s == nil {
		t.Fatal("expected non-nil Strategy")
	}
	if s.retries != 3 {
		t.Errorf("retries = %d, want 3", s.retries)
	}
}

func TestNewStrategy_DefaultValues(t *testing.T) {
	s := NewStrategy(nil, 0)
	if s == nil {
		t.Fatal("expected non-nil Strategy")
	}
	if s.client == nil {
		t.Error("expected non-nil client")
	}
	if s.retries != 0 {
		t.Errorf("retries = %d, want 0", s.retries)
	}
}

func TestDownload_NoURL(t *testing.T) {
	s := NewStrategy(nil, 0)
	_, err := s.Download(context.Background(), AudioRequest{
		URL:      "",
		FilePath: "/tmp/test.flac",
	})
	if err == nil {
		t.Fatal("expected error for empty URL")
	}
	if !strings.Contains(err.Error(), "no URL") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestDownload_NoFilePath(t *testing.T) {
	s := NewStrategy(nil, 0)
	_, err := s.Download(context.Background(), AudioRequest{
		URL:      "https://example.com/test.flac",
		FilePath: "",
	})
	if err == nil {
		t.Fatal("expected error for empty file path")
	}
	if !strings.Contains(err.Error(), "no file path") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestAudioRequest_Fields(t *testing.T) {
	req := AudioRequest{
		URL:          "https://example.com/stream.flac",
		TrackID:      "track_123",
		FilePath:     "/music/test.flac",
		Format:       "flac",
		ExpectedSize: 1000000,
	}
	if req.URL != "https://example.com/stream.flac" {
		t.Errorf("URL = %q", req.URL)
	}
	if req.TrackID != "track_123" {
		t.Errorf("TrackID = %q", req.TrackID)
	}
	if req.ExpectedSize != 1000000 {
		t.Errorf("ExpectedSize = %d", req.ExpectedSize)
	}
}

func TestAudioResult_Fields(t *testing.T) {
	r := AudioResult{
		FilePath:     "/music/test.flac",
		Size:         1000000,
		Format:       "flac",
		BytesWritten: 1000000,
	}
	if r.FilePath != "/music/test.flac" {
		t.Errorf("FilePath = %q", r.FilePath)
	}
	if r.Size != 1000000 {
		t.Errorf("Size = %d", r.Size)
	}
	if r.BytesWritten != 1000000 {
		t.Errorf("BytesWritten = %d", r.BytesWritten)
	}
}

func TestAudioResult_DefaultValues(t *testing.T) {
	r := AudioResult{}
	if r.FilePath != "" {
		t.Error("expected empty FilePath")
	}
	if r.Size != 0 {
		t.Errorf("Size = %d, want 0", r.Size)
	}
}

func TestDownload_CancelledContext(t *testing.T) {
	s := NewStrategy(nil, 1)

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := s.Download(ctx, AudioRequest{
		URL:      "https://example.com/test.flac",
		FilePath: "/tmp/test.flac",
	})
	if err == nil {
		t.Fatal("expected error for cancelled context")
	}
}

func TestDefaultUserAgent(t *testing.T) {
	if DefaultUserAgent != "Bitly/1.0" {
		t.Errorf("DefaultUserAgent = %q, want %q", DefaultUserAgent, "Bitly/1.0")
	}
}

func TestAudioRequest_EmptyFormat(t *testing.T) {
	req := AudioRequest{URL: "https://example.com/song.mp3"}
	if req.Format != "" {
		t.Error("expected empty Format")
	}
}

func TestParseContentRange(t *testing.T) {
	tests := []struct {
		header       string
		wantStart    int64
		wantEnd      int64
		wantTotal    int64
		wantErr      bool
	}{
		{"bytes 0-999/1000", 0, 999, 1000, false},
		{"bytes 100-199/500", 100, 199, 500, false},
		{"invalid", 0, 0, 0, true},
	}
	for _, tt := range tests {
		start, end, total, err := ParseContentRange(tt.header)
		if tt.wantErr {
			if err == nil {
				t.Errorf("ParseContentRange(%q) expected error", tt.header)
			}
			continue
		}
		if err != nil {
			t.Errorf("ParseContentRange(%q) unexpected error: %v", tt.header, err)
			continue
		}
		if start != tt.wantStart || end != tt.wantEnd || total != tt.wantTotal {
			t.Errorf("ParseContentRange(%q) = (%d,%d,%d), want (%d,%d,%d)",
				tt.header, start, end, total, tt.wantStart, tt.wantEnd, tt.wantTotal)
		}
	}
}
