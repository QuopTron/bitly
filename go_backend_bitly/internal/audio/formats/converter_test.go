package formats

import (
	"context"
	"strings"
	"testing"
)

func TestNewConverter(t *testing.T) {
	c := NewConverter("/usr/bin/ffmpeg")
	if c == nil {
		t.Fatal("expected non-nil Converter")
	}
}

func TestNewConverter_EmptyPath(t *testing.T) {
	c := NewConverter("")
	if c == nil {
		t.Fatal("expected non-nil Converter even with empty path")
	}
}

func TestConvert_NoFFmpeg(t *testing.T) {
	c := NewConverter("")
	_, err := c.Convert(context.Background(), ConvertRequest{
		SourceFile:   "test.flac",
		TargetFormat: "mp3",
	})
	if err == nil {
		t.Fatal("expected error when ffmpeg not configured")
	}
	if !strings.Contains(err.Error(), "ffmpeg not configured") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestConvert_UnsupportedFormat(t *testing.T) {
	c := NewConverter("/usr/bin/ffmpeg")
	_, err := c.Convert(context.Background(), ConvertRequest{
		SourceFile:   "test.flac",
		TargetFormat: "wma",
	})
	if err == nil {
		t.Fatal("expected error for unsupported format")
	}
	if !strings.Contains(err.Error(), "unsupported target format") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestConvertRequest_Fields(t *testing.T) {
	req := ConvertRequest{
		SourceFile:   "/music/song.flac",
		TargetFormat: "mp3",
		Quality:      "best",
		Bitrate:      320,
		SampleRate:   44100,
	}
	if req.SourceFile != "/music/song.flac" {
		t.Errorf("SourceFile = %q", req.SourceFile)
	}
	if req.TargetFormat != "mp3" {
		t.Errorf("TargetFormat = %q", req.TargetFormat)
	}
	if req.Bitrate != 320 {
		t.Errorf("Bitrate = %d", req.Bitrate)
	}
	if req.SampleRate != 44100 {
		t.Errorf("SampleRate = %d", req.SampleRate)
	}
}

func TestConvertResult_Fields(t *testing.T) {
	r := ConvertResult{
		OutputFile: "/music/song.mp3",
		Format:     "mp3",
		Size:       1024,
	}
	if r.OutputFile != "/music/song.mp3" {
		t.Errorf("OutputFile = %q", r.OutputFile)
	}
	if r.Format != "mp3" {
		t.Errorf("Format = %q", r.Format)
	}
	if r.Size != 1024 {
		t.Errorf("Size = %d", r.Size)
	}
}

func TestConvertResult_ZeroSize(t *testing.T) {
	r := ConvertResult{OutputFile: "/dev/null", Format: "flac"}
	if r.Size != 0 {
		t.Errorf("expected Size 0, got %d", r.Size)
	}
}

func TestConvertRequest_EmptySource(t *testing.T) {
	// Just verify struct fields
	req := ConvertRequest{}
	if req.SourceFile != "" {
		t.Error("expected empty SourceFile")
	}
	if req.TargetFormat != "" {
		t.Error("expected empty TargetFormat")
	}
}
