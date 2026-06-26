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

// ResampleRequest describes a resampling operation.
type ResampleRequest struct {
	SourceFile string `json:"source_file"`
	SampleRate int    `json:"sample_rate"`            // Target sample rate in Hz (e.g., 44100, 48000, 96000)
	BitDepth   int    `json:"bit_depth,omitempty"`    // Target bit depth (e.g., 16, 24, 32). 0 = keep original.
	OutputFile string `json:"output_file,omitempty"`  // Optional output path. Auto-generated if empty.
}

// ResampleResult describes the result of resampling.
type ResampleResult struct {
	OutputFile string `json:"output_file"`
	SampleRate int    `json:"sample_rate"`
	BitDepth   int    `json:"bit_depth,omitempty"`
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

// sampleFormatForBitDepth returns the FFmpeg sample format string
// for the given bit depth. Returns empty string for unsupported depths.
func sampleFormatForBitDepth(bitDepth int) string {
	switch bitDepth {
	case 16:
		return "s16"
	case 24:
		return "s24"
	case 32:
		return "s32"
	case 64:
		return "s64"
	default:
		return ""
	}
}

// Resample changes the sample rate and/or bit depth of an audio file.
// Keeps the same container format (e.g., FLAC in -> FLAC out).
func (c *Converter) Resample(ctx context.Context, req ResampleRequest) (*ResampleResult, error) {
	if c.ffmpegPath == "" {
		return nil, fmt.Errorf("ffmpeg not configured")
	}
	if req.SampleRate <= 0 && req.BitDepth <= 0 {
		return nil, fmt.Errorf("at least one of sample_rate or bit_depth must be specified")
	}

	// Validate bit depth before building args
	if req.BitDepth > 0 && sampleFormatForBitDepth(req.BitDepth) == "" {
		return nil, fmt.Errorf("unsupported bit depth: %d (supported: 16, 24, 32, 64)", req.BitDepth)
	}

	// Determine output path
	outputFile := req.OutputFile
	if outputFile == "" {
		ext := filepath.Ext(req.SourceFile)
		base := strings.TrimSuffix(req.SourceFile, ext)
		if req.SampleRate > 0 && req.BitDepth > 0 {
			outputFile = fmt.Sprintf("%s_%dhz_%dbit%s", base, req.SampleRate, req.BitDepth, ext)
		} else if req.SampleRate > 0 {
			outputFile = fmt.Sprintf("%s_%dhz%s", base, req.SampleRate, ext)
		} else {
			outputFile = fmt.Sprintf("%s_%dbit%s", base, req.BitDepth, ext)
		}
	}

	srcExt := strings.ToLower(filepath.Ext(req.SourceFile))
	args := []string{"-i", req.SourceFile, "-y", "-vn"}

	// Select audio codec based on source format and target bit depth
	switch srcExt {
	case ".flac":
		args = append(args, "-c:a", "flac", "-compression_level", "8")
	case ".m4a", ".mp4":
		args = append(args, "-c:a", "alac")
	case ".mp3":
		args = append(args, "-c:a", "libmp3lame", "-b:a", "320k")
	case ".opus", ".ogg":
		args = append(args, "-c:a", "libopus", "-b:a", "128k")
	case ".wav":
		// Choose PCM codec matching the target bit depth
		if req.BitDepth > 0 {
			fmt := sampleFormatForBitDepth(req.BitDepth)
			args = append(args, "-c:a", "pcm_"+fmt+"le")
		} else {
			args = append(args, "-c:a", "pcm_s16le")
		}
	default:
		args = append(args, "-c:a", "copy")
	}

	// Set sample rate
	if req.SampleRate > 0 {
		args = append(args, "-ar", fmt.Sprintf("%d", req.SampleRate))
	}

	// Set bit depth via sample format (not for WAV, already handled above)
	if req.BitDepth > 0 && srcExt != ".wav" {
		args = append(args, "-sample_fmt", sampleFormatForBitDepth(req.BitDepth))
	}

	args = append(args, outputFile)

	cmd := exec.CommandContext(ctx, c.ffmpegPath, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("ffmpeg resample failed: %w\nOutput: %s", err, string(output))
	}

	return &ResampleResult{
		OutputFile: outputFile,
		SampleRate: req.SampleRate,
		BitDepth:   req.BitDepth,
	}, nil
}
