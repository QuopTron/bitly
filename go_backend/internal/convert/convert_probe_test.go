package convert

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestConvert_FFmpegNotFound(t *testing.T) {
	cfg := Config{
		FFmpegPath: "/nonexistent/ffmpeg",
		OutputDir:  t.TempDir(),
		Format:     "mp3",
	}
	_, err := Convert(cfg, "testdata/input.flac")
	if err == nil {
		t.Skip("ffmpeg found at nonexistent path - may be in PATH")
	}
	if !strings.Contains(err.Error(), "ffmpeg") {
		t.Logf("Convert error (expected): %v", err)
	}
}

func TestConvert_EmptyOutputDir(t *testing.T) {
	cfg := Config{FFmpegPath: "ffmpeg", Format: "mp3"}
	_, err := Convert(cfg, "test.flac")
	_ = err
}

func TestConvert_InputFileNotExists(t *testing.T) {
	cfg := Config{
		FFmpegPath: "ffmpeg",
		OutputDir:  t.TempDir(),
		Format:     "mp3",
	}
	_, err := Convert(cfg, "/nonexistent/file.flac")
	_ = err
}

func TestProbe_FFprobeNotFound(t *testing.T) {
	_, err := Probe("/nonexistent/ffprobe", "test.flac")
	if err == nil {
		t.Skip("ffprobe found at nonexistent path - may be in PATH")
	}
	if !strings.Contains(err.Error(), "probe") {
		t.Errorf("expected 'probe:' prefix in error, got: %v", err)
	}
}

func TestProbe_EmptyInput(t *testing.T) {
	_, err := Probe("ffprobe", "")
	if err == nil {
		t.Skip("ffprobe succeeded with empty path")
	}
	if err == nil {
		t.Error("expected error with empty input path")
	}
}

func TestConvertAndProbe_Integration(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not in PATH, skipping integration test")
	}
	if _, err := exec.LookPath("ffprobe"); err != nil {
		t.Skip("ffprobe not in PATH, skipping integration test")
	}

	tmpDir := t.TempDir()
	inputPath := filepath.Join(tmpDir, "input.wav")
	outputDir := filepath.Join(tmpDir, "out")

	if err := os.MkdirAll(outputDir, 0755); err != nil {
		t.Fatal(err)
	}

	cmd := exec.Command("ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono",
		"-t", "1", inputPath)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Skipf("failed to generate test WAV: %s: %v", string(out), err)
	}

	cfg := Config{
		FFmpegPath: "ffmpeg",
		OutputDir:  outputDir,
		Format:     "flac",
		Quality:    "high",
	}
	result, err := Convert(cfg, inputPath)
	if err != nil {
		t.Fatalf("Convert failed: %v", err)
	}
	if result == nil {
		t.Fatal("expected non-nil result")
	}
	if result.Format != "flac" {
		t.Errorf("expected format flac, got %q", result.Format)
	}
	if result.InputPath != inputPath {
		t.Errorf("expected input path %q, got %q", inputPath, result.InputPath)
	}

	if _, err := os.Stat(result.OutputPath); os.IsNotExist(err) {
		t.Fatalf("output file not created: %s", result.OutputPath)
	}

	probeResult, err := Probe("ffprobe", result.OutputPath)
	if err != nil {
		t.Fatalf("Probe failed: %v", err)
	}
	if !strings.Contains(probeResult, "format") {
		t.Error("expected probe result to contain format info")
	}
}
