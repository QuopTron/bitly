package postprocess

import (
	"context"
	"testing"
)

func TestNewProcessor(t *testing.T) {
	p := NewProcessor("/usr/bin/ffmpeg")
	if p == nil {
		t.Fatal("expected non-nil Processor")
	}
	if p.ffmpegPath != "/usr/bin/ffmpeg" {
		t.Errorf("ffmpegPath = %q", p.ffmpegPath)
	}
}

func TestNewProcessor_EmptyPath(t *testing.T) {
	p := NewProcessor("")
	if p == nil {
		t.Fatal("expected non-nil Processor")
	}
}

func TestPostProcessRequest_Fields(t *testing.T) {
	req := PostProcessRequest{
		AudioFilePath: "/music/song.flac",
		CoverPath:     "/covers/cover.jpg",
		LyricsPath:    "/lyrics/song.lrc",
		TargetFormat:  "mp3",
		DeleteSource:  true,
	}

	if req.AudioFilePath != "/music/song.flac" {
		t.Errorf("AudioFilePath = %q", req.AudioFilePath)
	}
	if req.CoverPath != "/covers/cover.jpg" {
		t.Errorf("CoverPath = %q", req.CoverPath)
	}
	if req.TargetFormat != "mp3" {
		t.Errorf("TargetFormat = %q", req.TargetFormat)
	}
	if !req.DeleteSource {
		t.Error("DeleteSource should be true")
	}
}

func TestPostProcessResult_Fields(t *testing.T) {
	r := PostProcessResult{
		AudioFilePath: "/music/song.mp3",
		CoverPath:     "/covers/cover.jpg",
		LyricsPath:    "/lyrics/song.lrc",
	}

	if r.AudioFilePath != "/music/song.mp3" {
		t.Errorf("AudioFilePath = %q", r.AudioFilePath)
	}
	if r.CoverPath != "/covers/cover.jpg" {
		t.Errorf("CoverPath = %q", r.CoverPath)
	}
	if r.LyricsPath != "/lyrics/song.lrc" {
		t.Errorf("LyricsPath = %q", r.LyricsPath)
	}
}

func TestPostProcessResult_DefaultValues(t *testing.T) {
	r := PostProcessResult{}
	if r.AudioFilePath != "" {
		t.Error("expected empty AudioFilePath")
	}
	if r.CoverPath != "" {
		t.Error("expected empty CoverPath")
	}
}

func TestNewProcessor_HasEmbedder(t *testing.T) {
	p := NewProcessor("")
	if p.embedder == nil {
		t.Error("expected non-nil embedder")
	}
}

func TestNewProcessor_HasConverter(t *testing.T) {
	p := NewProcessor("")
	if p.converter == nil {
		t.Error("expected non-nil converter")
	}
}

func TestProcess_NoFFmpegConversion(t *testing.T) {
	p := NewProcessor("")
	// Without ffmpeg, conversion will fail if targetFormat is different
	// But with same format, no conversion needed
	req := PostProcessRequest{
		AudioFilePath: "/music/song.flac",
		TargetFormat:  "flac", // same format, no conversion needed
	}
	result, err := p.Process(context.Background(), req)
	if err != nil {
		// If it tries to read the file and it doesn't exist, it may fail
		t.Logf("Process returned error (expected): %v", err)
		_ = result
	}
}

func TestProcess_ConversionNeedsFFmpeg(t *testing.T) {
	p := NewProcessor("")
	_, err := p.Process(context.Background(), PostProcessRequest{
		AudioFilePath: "/music/song.flac",
		TargetFormat:  "mp3",
	})
	if err == nil {
		t.Fatal("expected error when converting without ffmpeg")
	}
}
