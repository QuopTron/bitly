package convert

import "testing"

func TestBuildArgs_QualityLossless(t *testing.T) {
	cfg := Config{Format: "flac", Quality: "lossless"}
	args := buildArgs(cfg, "input.flac", "output.flac")

	if !containsArg(args, "8") {
		t.Errorf("expected compression_level 8 for lossless quality, got: %v", args)
	}
}

func TestBuildArgs_ALACOutputExt(t *testing.T) {
	cfg := Config{Format: "alac"}
	args := buildArgs(cfg, "test.flac", "test.m4a")
	if !containsArg(args, "alac") {
		t.Errorf("expected alac codec in args, got: %v", args)
	}
}

func TestBuildArgs_OutputPathOrder(t *testing.T) {
	cfg := Config{Format: "mp3", Quality: "high"}
	args := buildArgs(cfg, "input.wav", "output.mp3")

	last := args[len(args)-1]
	if last != "output.mp3" {
		t.Errorf("expected output path as last arg, got: %s", last)
	}
}
