package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/formats"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/postprocess"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

// PostProcessInputV2 mirrors the old backend's PostProcessInput struct.
type PostProcessInputV2 struct {
	FilePath     string `json:"file_path"`
	OutputFormat string `json:"output_format,omitempty"`
	DeleteSource bool   `json:"delete_source,omitempty"`
}

// findFFmpegPath attempts to locate the ffmpeg binary.
func findFFmpegPath() string {
	// Try PATH first
	if path, err := exec.LookPath("ffmpeg"); err == nil {
		return path
	}
	// On Windows, try ffmpeg.exe
	if path, err := exec.LookPath("ffmpeg.exe"); err == nil {
		return path
	}
	// Check alongside the running executable
	exe, err := os.Executable()
	if err == nil {
		dir := filepath.Dir(exe)
		candidate := filepath.Join(dir, "ffmpeg.exe")
		if _, statErr := os.Stat(candidate); statErr == nil {
			return candidate
		}
		candidate = filepath.Join(dir, "ffmpeg")
		if _, statErr := os.Stat(candidate); statErr == nil {
			return candidate
		}
	}
	return ""
}

// RegisterPostProcessingHandlers registers post-processing RPC methods.
// These provide format conversion and metadata embedding via FFmpeg.
func RegisterPostProcessingHandlers(reg *rpc.Registry) {
	reg.Register("runPostProcessing", func(params map[string]interface{}) (interface{}, error) {
		filePath := rpc.Sp(params, "file_path")
		metadataJSON := rpc.Sp(params, "metadata")
		if filePath == "" {
			return "", fmt.Errorf("file_path is required")
		}

		ffmpegPath := findFFmpegPath()
		if ffmpegPath == "" {
			// No FFmpeg available — return passthrough
			result := map[string]interface{}{
				"method":  "passthrough",
				"success": true,
				"file":    filePath,
				"warning": "ffmpeg not found",
			}
			if metadataJSON != "" {
				var meta map[string]interface{}
				if err := json.Unmarshal([]byte(metadataJSON), &meta); err == nil {
					result["metadata"] = meta
				}
			}
			out, _ := json.Marshal(result)
			return string(out), nil
		}

		// Parse metadata from JSON
		var metaFields map[string]interface{}
		if metadataJSON != "" {
			json.Unmarshal([]byte(metadataJSON), &metaFields)
		}

		// Build post-processing request
		req := postprocess.PostProcessRequest{
			AudioFilePath: filePath,
			DeleteSource:  false,
		}

		// If a target format is specified in metadata, convert
		if format, ok := metaFields["target_format"].(string); ok && format != "" {
			req.TargetFormat = format
			req.DeleteSource = true
		}

		// Build tags from metadata
		if title, ok := metaFields["title"].(string); ok && title != "" {
			req.Tags.Title = title
		}
		if artist, ok := metaFields["artist"].(string); ok && artist != "" {
			req.Tags.Artist = artist
		}
		if album, ok := metaFields["album"].(string); ok && album != "" {
			req.Tags.Album = album
		}
		if albumArtist, ok := metaFields["album_artist"].(string); ok && albumArtist != "" {
			req.Tags.AlbumArtist = albumArtist
		}
		if genre, ok := metaFields["genre"].(string); ok && genre != "" {
			req.Tags.Genre = genre
		}
		if date, ok := metaFields["date"].(string); ok && date != "" {
			req.Tags.Date = date
		}
		if isrc, ok := metaFields["isrc"].(string); ok && isrc != "" {
			req.Tags.ISRC = isrc
		}
		if trackNum, ok := metaFields["track_number"].(float64); ok {
			req.Tags.TrackNumber = int(trackNum)
		}
		if totalTracks, ok := metaFields["total_tracks"].(float64); ok {
			req.Tags.TotalTracks = int(totalTracks)
		}
		if discNum, ok := metaFields["disc_number"].(float64); ok {
			req.Tags.DiscNumber = int(discNum)
		}
		if totalDiscs, ok := metaFields["total_discs"].(float64); ok {
			req.Tags.TotalDiscs = int(totalDiscs)
		}
		if label, ok := metaFields["label"].(string); ok && label != "" {
			req.Tags.Label = label
		}
		if copyright, ok := metaFields["copyright"].(string); ok && copyright != "" {
			req.Tags.Copyright = copyright
		}
		if composer, ok := metaFields["composer"].(string); ok && composer != "" {
			req.Tags.Composer = composer
		}
		if lyrics, ok := metaFields["lyrics"].(string); ok && lyrics != "" {
			req.Tags.Lyrics = lyrics
		}
		if coverPath, ok := metaFields["cover_path"].(string); ok && coverPath != "" {
			req.CoverPath = coverPath
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()

		proc := postprocess.NewProcessor(ffmpegPath)
		result, err := proc.Process(ctx, req)
		if err != nil {
			return "", fmt.Errorf("post-processing failed: %w", err)
		}

		resp := map[string]interface{}{
			"method":          "ffmpeg",
			"success":         true,
			"file":            result.AudioFilePath,
			"output_file":     result.AudioFilePath,
		}
		out, _ := json.Marshal(resp)
		return string(out), nil
	})

	reg.Register("runPostProcessingV2", func(params map[string]interface{}) (interface{}, error) {
		inputJSON := rpc.Sp(params, "input")
		metadataJSON := rpc.Sp(params, "metadata")
		if inputJSON == "" {
			return "", fmt.Errorf("input is required")
		}

		var input PostProcessInputV2
		if err := json.Unmarshal([]byte(inputJSON), &input); err != nil {
			return "", fmt.Errorf("invalid input JSON: %w", err)
		}
		if input.FilePath == "" {
			return "", fmt.Errorf("input.file_path is required")
		}

		ffmpegPath := findFFmpegPath()
		if ffmpegPath == "" {
			result := map[string]interface{}{
				"method":  "passthrough",
				"success": true,
				"input":   input.FilePath,
				"warning": "ffmpeg not found",
			}
			if metadataJSON != "" {
				var meta map[string]interface{}
				if err := json.Unmarshal([]byte(metadataJSON), &meta); err == nil {
					result["metadata"] = meta
				}
			}
			out, _ := json.Marshal(result)
			return string(out), nil
		}

		var metaFields map[string]interface{}
		if metadataJSON != "" {
			json.Unmarshal([]byte(metadataJSON), &metaFields)
		}

		req := postprocess.PostProcessRequest{
			AudioFilePath: input.FilePath,
			DeleteSource:  input.DeleteSource,
			TargetFormat:  input.OutputFormat,
		}

		if title, ok := metaFields["title"].(string); ok && title != "" {
			req.Tags.Title = title
		}
		if artist, ok := metaFields["artist"].(string); ok && artist != "" {
			req.Tags.Artist = artist
		}
		if album, ok := metaFields["album"].(string); ok && album != "" {
			req.Tags.Album = album
		}
		if albumArtist, ok := metaFields["album_artist"].(string); ok && albumArtist != "" {
			req.Tags.AlbumArtist = albumArtist
		}
		if genre, ok := metaFields["genre"].(string); ok && genre != "" {
			req.Tags.Genre = genre
		}
		if date, ok := metaFields["date"].(string); ok && date != "" {
			req.Tags.Date = date
		}
		if isrc, ok := metaFields["isrc"].(string); ok && isrc != "" {
			req.Tags.ISRC = isrc
		}
		if trackNum, ok := metaFields["track_number"].(float64); ok {
			req.Tags.TrackNumber = int(trackNum)
		}
		if totalTracks, ok := metaFields["total_tracks"].(float64); ok {
			req.Tags.TotalTracks = int(totalTracks)
		}
		if discNum, ok := metaFields["disc_number"].(float64); ok {
			req.Tags.DiscNumber = int(discNum)
		}
		if totalDiscs, ok := metaFields["total_discs"].(float64); ok {
			req.Tags.TotalDiscs = int(totalDiscs)
		}
		if label, ok := metaFields["label"].(string); ok && label != "" {
			req.Tags.Label = label
		}
		if copyright, ok := metaFields["copyright"].(string); ok && copyright != "" {
			req.Tags.Copyright = copyright
		}
		if composer, ok := metaFields["composer"].(string); ok && composer != "" {
			req.Tags.Composer = composer
		}
		if lyrics, ok := metaFields["lyrics"].(string); ok && lyrics != "" {
			req.Tags.Lyrics = lyrics
		}
		if coverPath, ok := metaFields["cover_path"].(string); ok && coverPath != "" {
			req.CoverPath = coverPath
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()

		proc := postprocess.NewProcessor(ffmpegPath)
		result, err := proc.Process(ctx, req)
		if err != nil {
			return "", fmt.Errorf("post-processing failed: %w", err)
		}

		resp := map[string]interface{}{
			"method":      "ffmpeg",
			"success":     true,
			"output_file": result.AudioFilePath,
			"file_path":   result.AudioFilePath,
		}
		out, _ := json.Marshal(resp)
		return string(out), nil
	})

	reg.Register("getPostProcessingProviders", func(params map[string]interface{}) (interface{}, error) {
		// New backend uses native post-processing via FFmpeg, no extension-based providers.
		// Return an empty list for compatibility.
		return "[]", nil
	})

	reg.Register("convertAudioFile", func(params map[string]interface{}) (interface{}, error) {
		inputPath := rpc.Sp(params, "input_path")
		if inputPath == "" {
			return "", fmt.Errorf("input_path is required")
		}
		lower := strings.ToLower(inputPath)
		if !strings.HasSuffix(lower, ".m4a") {
			// Not an m4a file, return the input path unchanged
			return inputPath, nil
		}

		ffmpegPath := findFFmpegPath()
		if ffmpegPath == "" {
			return inputPath, nil
		}

		conv := formats.NewConverter(ffmpegPath)
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()

		result, err := conv.Convert(ctx, formats.ConvertRequest{
			SourceFile:   inputPath,
			TargetFormat: "flac",
			Quality:      "best",
		})
		if err != nil {
			// Conversion failed, return input path unchanged
			return inputPath, nil
		}

		// Remove original m4a file on success
		os.Remove(inputPath)

		return result.OutputFile, nil
	})

	reg.Register("resampleAudio", func(params map[string]interface{}) (interface{}, error) {
		filePath := rpc.Sp(params, "file_path")
		if filePath == "" {
			return "", fmt.Errorf("file_path is required")
		}

		sampleRate := rpc.Sn(params, "sample_rate")
		bitDepth := rpc.Sn(params, "bit_depth")

		if sampleRate <= 0 && bitDepth <= 0 {
			return "", fmt.Errorf("at least one of sample_rate or bit_depth must be specified")
		}

		ffmpegPath := findFFmpegPath()
		if ffmpegPath == "" {
			return "", fmt.Errorf("ffmpeg not found")
		}

		outputFile := rpc.Sp(params, "output_file")

		conv := formats.NewConverter(ffmpegPath)
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()

		result, err := conv.Resample(ctx, formats.ResampleRequest{
			SourceFile: filePath,
			SampleRate: sampleRate,
			BitDepth:   bitDepth,
			OutputFile: outputFile,
		})
		if err != nil {
			return "", fmt.Errorf("resample failed: %w", err)
		}

		resp := map[string]interface{}{
			"success":     true,
			"output_file": result.OutputFile,
			"sample_rate": result.SampleRate,
			"bit_depth":   result.BitDepth,
		}
		out, _ := json.Marshal(resp)
		return string(out), nil
	})
}
