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

// --- Resample tests ---

func TestResample_NoFFmpeg(t *testing.T) {
	c := NewConverter("")
	_, err := c.Resample(context.Background(), ResampleRequest{
		SourceFile: "test.flac",
		SampleRate: 44100,
	})
	if err == nil {
		t.Fatal("expected error when ffmpeg not configured")
	}
	if !strings.Contains(err.Error(), "ffmpeg not configured") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestResample_NoParams(t *testing.T) {
	c := NewConverter("/usr/bin/ffmpeg")
	_, err := c.Resample(context.Background(), ResampleRequest{
		SourceFile: "test.flac",
	})
	if err == nil {
		t.Fatal("expected error when no params specified")
	}
	if !strings.Contains(err.Error(), "at least one of") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestResampleRequest_Fields(t *testing.T) {
	req := ResampleRequest{
		SourceFile: "/music/song.flac",
		SampleRate: 96000,
		BitDepth:   24,
		OutputFile: "/music/song_remastered.flac",
	}
	if req.SourceFile != "/music/song.flac" {
		t.Errorf("SourceFile = %q", req.SourceFile)
	}
	if req.SampleRate != 96000 {
		t.Errorf("SampleRate = %d", req.SampleRate)
	}
	if req.BitDepth != 24 {
		t.Errorf("BitDepth = %d", req.BitDepth)
	}
	if req.OutputFile != "/music/song_remastered.flac" {
		t.Errorf("OutputFile = %q", req.OutputFile)
	}
}

func TestResampleResult_Fields(t *testing.T) {
	r := ResampleResult{
		OutputFile: "/music/song_44khz.flac",
		SampleRate: 44100,
		BitDepth:   16,
	}
	if r.OutputFile != "/music/song_44khz.flac" {
		t.Errorf("OutputFile = %q", r.OutputFile)
	}
	if r.SampleRate != 44100 {
		t.Errorf("SampleRate = %d", r.SampleRate)
	}
	if r.BitDepth != 16 {
		t.Errorf("BitDepth = %d", r.BitDepth)
	}
}

func TestResampleResult_DefaultBitDepth(t *testing.T) {
	r := ResampleResult{OutputFile: "/out.flac", SampleRate: 48000}
	if r.BitDepth != 0 {
		t.Errorf("expected 0 bit depth, got %d", r.BitDepth)
	}
}

func TestSampleFormatForBitDepth(t *testing.T) {
	tests := []struct {
		bitDepth int
		expected string
	}{
		{16, "s16"},
		{24, "s24"},
		{32, "s32"},
		{64, "s64"},
		{0, ""},
		{8, ""},
		{128, ""},
	}
	for _, tc := range tests {
		got := sampleFormatForBitDepth(tc.bitDepth)
		if got != tc.expected {
			t.Errorf("sampleFormatForBitDepth(%d) = %q, want %q", tc.bitDepth, got, tc.expected)
		}
	}
}

func TestResample_SampleRateOnly(t *testing.T) {
	c := NewConverter("/usr/bin/ffmpeg")
	req := ResampleRequest{
		SourceFile: "test.flac",
		SampleRate: 44100,
	}
	// Without ffmpeg, this should fail, but check the error is from ffmpeg execution
	// not from validation
	_, err := c.Resample(context.Background(), req)
	if err == nil {
		t.Fatal("expected error (ffmpeg not found)")
	}
	// Should NOT say "ffmpeg not configured" or "at least one of"
	if strings.Contains(err.Error(), "ffmpeg not configured") ||
		strings.Contains(err.Error(), "at least one of") {
		t.Errorf("unexpected validation error: %v", err)
	}
}

func TestResample_BitDepthOnly(t *testing.T) {
	c := NewConverter("/usr/bin/ffmpeg")
	req := ResampleRequest{
		SourceFile: "test.flac",
		BitDepth:   16,
	}
	_, err := c.Resample(context.Background(), req)
	if err == nil {
		t.Fatal("expected error (ffmpeg not found)")
	}
	if strings.Contains(err.Error(), "ffmpeg not configured") ||
		strings.Contains(err.Error(), "at least one of") {
		t.Errorf("unexpected validation error: %v", err)
	}
}
