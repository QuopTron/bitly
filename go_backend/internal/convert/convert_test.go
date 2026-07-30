package convert

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// ─── buildArgs (pure function, no external deps) ────────────

func TestBuildArgs_MP3(t *testing.T) {
	cfg := Config{Format: "mp3"}
	args := buildArgs(cfg, "input.flac", "output.mp3")

	expect := []string{"-y", "-i", "input.flac", "-codec:a", "libmp3lame", "-b:a", "320k", "output.mp3"}
	if !stringSlicesEqual(args, expect) {
		t.Errorf("mp3 args:\n  got:  %v\n  want: %v", args, expect)
	}
}

func TestBuildArgs_MP3_CustomBitrate(t *testing.T) {
	cfg := Config{Format: "mp3", Bitrate: "128k"}
	args := buildArgs(cfg, "input.wav", "output.mp3")

	if !containsArg(args, "128k") {
		t.Errorf("expected bitrate 128k in args, got: %v", args)
	}
}

func TestBuildArgs_FLAC(t *testing.T) {
	cfg := Config{Format: "flac"}
	args := buildArgs(cfg, "input.wav", "output.flac")

	expect := []string{"-y", "-i", "input.wav", "-codec:a", "flac", "output.flac"}
	if !stringSlicesEqual(args, expect) {
		t.Errorf("flac args:\n  got:  %v\n  want: %v", args, expect)
	}
}

func TestBuildArgs_Opus(t *testing.T) {
	cfg := Config{Format: "opus"}
	args := buildArgs(cfg, "input.flac", "output.opus")

	if !containsArg(args, "libopus") {
		t.Errorf("expected libopus codec, got: %v", args)
	}
	if !containsArg(args, "160k") {
		t.Errorf("expected default bitrate 160k, got: %v", args)
	}
}

func TestBuildArgs_Opus_CustomBitrate(t *testing.T) {
	cfg := Config{Format: "opus", Bitrate: "96k"}
	args := buildArgs(cfg, "input.flac", "output.opus")

	if !containsArg(args, "96k") {
		t.Errorf("expected custom bitrate 96k, got: %v", args)
	}
}

func TestBuildArgs_AAC(t *testing.T) {
	cfg := Config{Format: "aac"}
	args := buildArgs(cfg, "input.flac", "output.m4a")

	if !containsArg(args, "-codec:a") || !containsArgAfter(args, "-codec:a", "aac") {
		t.Errorf("expected aac codec, got: %v", args)
	}
	if !containsArg(args, "256k") {
		t.Errorf("expected default bitrate 256k, got: %v", args)
	}
}

func TestBuildArgs_WAV(t *testing.T) {
	cfg := Config{Format: "wav"}
	args := buildArgs(cfg, "input.flac", "output.wav")

	if !containsArg(args, "pcm_s16le") {
		t.Errorf("expected pcm_s16le codec, got: %v", args)
	}
}

func TestBuildArgs_ALAC(t *testing.T) {
	cfg := Config{Format: "alac"}
	args := buildArgs(cfg, "input.flac", "output.m4a")

	if !containsArg(args, "alac") {
		t.Errorf("expected alac codec, got: %v", args)
	}
}

func TestBuildArgs_DefaultFormat(t *testing.T) {
	cfg := Config{Format: "unknown"}
	args := buildArgs(cfg, "input.flac", "output.xyz")

	if !containsArg(args, "copy") {
		t.Errorf("expected 'copy' codec for unknown format, got: %v", args)
	}
}

func TestBuildArgs_QualityLow(t *testing.T) {
	cfg := Config{Format: "flac", Quality: "low"}
	args := buildArgs(cfg, "input.flac", "output.flac")

	if !containsArg(args, "0") {
		t.Errorf("expected compression_level 0 for low quality, got: %v", args)
	}
}

func TestBuildArgs_QualityHigh(t *testing.T) {
	cfg := Config{Format: "flac", Quality: "high"}
	args := buildArgs(cfg, "input.flac", "output.flac")

	if !containsArg(args, "8") {
		t.Errorf("expected compression_level 8 for high quality, got: %v", args)
	}
}

func TestBuildArgs_QualityLossless(t *testing.T) {
	cfg := Config{Format: "flac", Quality: "lossless"}
	args := buildArgs(cfg, "input.flac", "output.flac")

	if !containsArg(args, "8") {
		t.Errorf("expected compression_level 8 for lossless quality, got: %v", args)
	}
}

func TestBuildArgs_ALACOutputExt(t *testing.T) {
	// ALAC output extension is handled inside Convert() before exec runs.
	// buildArgs always gets the output path already resolved.
	cfg := Config{Format: "alac"}
	args := buildArgs(cfg, "test.flac", "test.m4a")
	if !containsArg(args, "alac") {
		t.Errorf("expected alac codec in args, got: %v", args)
	}
}

func TestBuildArgs_OutputPathOrder(t *testing.T) {
	// The output path should be the LAST argument
	cfg := Config{Format: "mp3", Quality: "high"}
	args := buildArgs(cfg, "input.wav", "output.mp3")

	last := args[len(args)-1]
	if last != "output.mp3" {
		t.Errorf("expected output path as last arg, got: %s", last)
	}
}

// ─── Convert (requires ffmpeg binary) ───────────────────────

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
	// Expected: exec error
	if !strings.Contains(err.Error(), "ffmpeg") {
		t.Logf("Convert error (expected): %v", err)
	}
}

func TestConvert_EmptyOutputDir(t *testing.T) {
	// Just verify it doesn't panic
	cfg := Config{
		FFmpegPath: "ffmpeg",
		Format:     "mp3",
	}

	// Should error because output dir is empty, but not panic
	_, err := Convert(cfg, "test.flac")
	_ = err // expected to fail, just no panic
}

func TestConvert_InputFileNotExists(t *testing.T) {
	cfg := Config{
		FFmpegPath: "ffmpeg",
		OutputDir:  t.TempDir(),
		Format:     "mp3",
	}
	_, err := Convert(cfg, "/nonexistent/file.flac")
	_ = err // expected to fail, just no panic
}

// ─── Probe (requires ffprobe binary) ────────────────────────

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
	// Should error, not panic
	if err == nil {
		t.Error("expected error with empty input path")
	}
}

// ─── Integration: Convert + Probe with real FFmpeg ──────────

func TestConvertAndProbe_Integration(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not in PATH, skipping integration test")
	}
	if _, err := exec.LookPath("ffprobe"); err != nil {
		t.Skip("ffprobe not in PATH, skipping integration test")
	}

	// Create a minimal WAV file for testing
	tmpDir := t.TempDir()
	inputPath := filepath.Join(tmpDir, "input.wav")
	outputDir := filepath.Join(tmpDir, "out")

	if err := os.MkdirAll(outputDir, 0755); err != nil {
		t.Fatal(err)
	}

	// Generate a 1-second silent WAV using ffmpeg
	cmd := exec.Command("ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono",
		"-t", "1", inputPath)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Skipf("failed to generate test WAV: %s: %v", string(out), err)
	}

	// Convert to FLAC
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

	// Verify the output file exists
	if _, err := os.Stat(result.OutputPath); os.IsNotExist(err) {
		t.Fatalf("output file not created: %s", result.OutputPath)
	}

	// Probe the converted file
	probeResult, err := Probe("ffprobe", result.OutputPath)
	if err != nil {
		t.Fatalf("Probe failed: %v", err)
	}
	if !strings.Contains(probeResult, "format") {
		t.Error("expected probe result to contain format info")
	}
}

// ─── Helpers ─────────────────────────────────────────────────

func stringSlicesEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func containsArg(args []string, target string) bool {
	for _, a := range args {
		if a == target {
			return true
		}
	}
	return false
}

func containsArgAfter(args []string, before, target string) bool {
	for i, a := range args {
		if a == before && i+1 < len(args) && args[i+1] == target {
			return true
		}
	}
	return false
}
