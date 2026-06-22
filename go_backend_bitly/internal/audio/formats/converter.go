package formats

import (
	"context"
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
)

// Converter handles audio format conversion via FFmpeg.
type Converter struct {
	ffmpegPath string
}

// ConvertRequest describes a conversion operation.
type ConvertRequest struct {
	SourceFile   string `json:"source_file"`
	TargetFormat string `json:"target_format"`
	Quality      string `json:"quality,omitempty"` // "best", "high", "medium", "low"
	Bitrate      int    `json:"bitrate,omitempty"` // Target bitrate in kbps
	SampleRate   int    `json:"sample_rate,omitempty"`
}

// ConvertResult describes the result of conversion.
type ConvertResult struct {
	OutputFile string `json:"output_file"`
	Format     string `json:"format"`
	Size       int64  `json:"size"`
}

// NewConverter creates a new format converter.
func NewConverter(ffmpegPath string) *Converter {
	return &Converter{ffmpegPath: ffmpegPath}
}

// Convert converts an audio file to the target format.
func (c *Converter) Convert(ctx context.Context, req ConvertRequest) (*ConvertResult, error) {
	if c.ffmpegPath == "" {
		return nil, fmt.Errorf("ffmpeg not configured")
	}

	ext := "." + req.TargetFormat
	outputFile := strings.TrimSuffix(req.SourceFile, filepath.Ext(req.SourceFile)) + ext

	args := []string{"-i", req.SourceFile, "-y"}

	switch req.TargetFormat {
	case "flac":
		args = append(args, "-c:a", "flac")
		args = append(args, "-compression_level", "8")
	case "mp3":
		args = append(args, "-c:a", "libmp3lame")
		if req.Bitrate > 0 {
			args = append(args, "-b:a", fmt.Sprintf("%dk", req.Bitrate))
		} else {
			args = append(args, "-b:a", "320k")
		}
	case "opus":
		args = append(args, "-c:a", "libopus")
		if req.Bitrate > 0 {
			args = append(args, "-b:a", fmt.Sprintf("%dk", req.Bitrate))
		} else {
			args = append(args, "-b:a", "128k")
		}
	case "alac":
		args = append(args, "-c:a", "alac")
	case "aac":
		args = append(args, "-c:a", "aac")
		if req.Bitrate > 0 {
			args = append(args, "-b:a", fmt.Sprintf("%dk", req.Bitrate))
		} else {
			args = append(args, "-b:a", "256k")
		}
	case "wav":
		args = append(args, "-c:a", "pcm_s16le")
	default:
		return nil, fmt.Errorf("unsupported target format: %s", req.TargetFormat)
	}

	if req.SampleRate > 0 {
		args = append(args, "-ar", fmt.Sprintf("%d", req.SampleRate))
	}

	args = append(args, outputFile)

	cmd := exec.CommandContext(ctx, c.ffmpegPath, args...)
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("ffmpeg conversion failed: %w", err)
	}

	return &ConvertResult{
		OutputFile: outputFile,
		Format:     req.TargetFormat,
	}, nil
}
