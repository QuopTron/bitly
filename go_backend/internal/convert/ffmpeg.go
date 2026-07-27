// Package convert wraps FFmpeg for audio format conversion.
package convert

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
)

// Config defines conversion parameters.
type Config struct {
	FFmpegPath string `json:"ffmpegPath"`
	OutputDir  string `json:"outputDir"`
	Quality    string `json:"quality"` // "low", "medium", "high", "lossless"
	Format     string `json:"format"`  // "mp3", "flac", "opus", "aac", "wav", "alac"
	Bitrate    string `json:"bitrate"` // e.g. "320k"
}

// Result holds conversion output info.
type Result struct {
	InputPath  string `json:"inputPath"`
	OutputPath string `json:"outputPath"`
	Format     string `json:"format"`
	Size       int64  `json:"size"`
}

// Convert runs FFmpeg to convert an audio file.
func Convert(cfg Config, inputPath string) (*Result, error) {
	ext := filepath.Ext(inputPath)
	base := strings.TrimSuffix(filepath.Base(inputPath), ext)

	outputExt := "." + cfg.Format
	if cfg.Format == "alac" {
		outputExt = ".m4a"
	}

	outputPath := filepath.Join(cfg.OutputDir, base+outputExt)

	args := buildArgs(cfg, inputPath, outputPath)
	cmd := exec.Command(cfg.FFmpegPath, args...)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("convert: ffmpeg failed: %s: %w", string(output), err)
	}

	return &Result{
		InputPath:  inputPath,
		OutputPath: outputPath,
		Format:     cfg.Format,
	}, nil
}

func buildArgs(cfg Config, input, output string) []string {
	args := []string{"-y", "-i", input}

	switch cfg.Format {
	case "mp3":
		bitrate := cfg.Bitrate
		if bitrate == "" {
			bitrate = "320k"
		}
		args = append(args, "-codec:a", "libmp3lame", "-b:a", bitrate)
	case "flac":
		args = append(args, "-codec:a", "flac")
	case "opus":
		bitrate := cfg.Bitrate
		if bitrate == "" {
			bitrate = "160k"
		}
		args = append(args, "-codec:a", "libopus", "-b:a", bitrate)
	case "aac":
		bitrate := cfg.Bitrate
		if bitrate == "" {
			bitrate = "256k"
		}
		args = append(args, "-codec:a", "aac", "-b:a", bitrate)
	case "wav":
		args = append(args, "-codec:a", "pcm_s16le")
	case "alac":
		args = append(args, "-codec:a", "alac")
	default:
		args = append(args, "-codec:a", "copy")
	}

	// Quality presets
	switch cfg.Quality {
	case "low":
		args = append(args, "-compression_level", "0")
	case "high", "lossless":
		args = append(args, "-compression_level", "8")
	}

	args = append(args, output)
	return args
}

// Probe returns file info using ffprobe.
func Probe(ffprobePath, inputPath string) (string, error) {
	cmd := exec.Command(ffprobePath, "-v", "quiet",
		"-print_format", "json",
		"-show_format", "-show_streams",
		inputPath)
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("probe: %w", err)
	}
	return string(output), nil
}
