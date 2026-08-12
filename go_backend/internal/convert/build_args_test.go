package convert

import "testing"

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
