package metadata

import (
	"fmt"
	"path/filepath"
	"strings"
)

// BuildDisplayAudioQuality builds a human-readable quality string.
func BuildDisplayAudioQuality(bitDepth, sampleRate, bitrateKbps int, format, storedQuality string) string {
	if storedQuality != "" {
		return storedQuality
	}
	var parts []string
	if bitDepth > 0 {
		parts = append(parts, fmt.Sprintf("%d-bit", bitDepth))
	}
	if sampleRate > 0 {
		parts = append(parts, fmt.Sprintf("%d kHz", sampleRate/1000))
	}
	if bitrateKbps > 0 && format != "FLAC" && format != "ALAC" {
		parts = append(parts, fmt.Sprintf("%d kbps", bitrateKbps))
	}
	if format != "" {
		parts = append(parts, format)
	}
	if len(parts) == 0 {
		return "Unknown"
	}
	return strings.Join(parts, " ")
}

// FormatSampleRateKHz formats sample rate as kHz string.
func FormatSampleRateKHz(sampleRate int) string {
	if sampleRate <= 0 {
		return ""
	}
	return fmt.Sprintf("%.1f kHz", float64(sampleRate)/1000.0)
}

// IsPlaceholderQualityLabel returns true if the quality label is a placeholder.
func IsPlaceholderQualityLabel(quality string) bool {
	if quality == "" {
		return true
	}
	lower := strings.ToLower(strings.TrimSpace(quality))
	return lower == "" || lower == "unknown" || lower == "standard" || lower == "auto"
}

// AudioMimeTypeForPath returns the MIME type for a given audio file path.
func AudioMimeTypeForPath(filePath string) string {
	ext := strings.ToLower(filepath.Ext(filePath))
	switch ext {
	case ".flac":
		return "audio/flac"
	case ".mp3":
		return "audio/mpeg"
	case ".m4a", ".aac":
		return "audio/mp4"
	case ".opus":
		return "audio/opus"
	case ".ogg":
		return "audio/ogg"
	case ".wav":
		return "audio/wav"
	case ".wma":
		return "audio/x-ms-wma"
	default:
		return "application/octet-stream"
	}
}
