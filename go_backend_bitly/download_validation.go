package gobackend

import (
	"fmt"
	"os"
	"time"

	flac "github.com/go-flac/go-flac/v2"
)

const (
	previewMaxDuration = 35 * time.Second
	previewMaxFileSize = int64(2 * 1024 * 1024)
	minFileSize        = int64(1024)
)

type ValidationResult struct {
	IsValid  bool
	Duration time.Duration
	Reason   string
}

func ValidateDownloadedFile(filePath string) ValidationResult {
	info, err := os.Stat(filePath)
	if err != nil {
		return ValidationResult{Reason: fmt.Sprintf("cannot stat file: %v", err)}
	}

	if info.Size() < minFileSize {
		return ValidationResult{
			Reason: fmt.Sprintf("file too small: %d bytes", info.Size()),
		}
	}

	if info.Size() < previewMaxFileSize {
		return ValidationResult{
			Reason: fmt.Sprintf("file too small (%d bytes), likely a preview", info.Size()),
		}
	}

	duration, err := getFLACDuration(filePath)
	if err != nil {
		return ValidationResult{IsValid: true, Duration: duration}
	}

	if duration > 0 && duration < previewMaxDuration {
		return ValidationResult{
			Duration: duration,
			Reason:   fmt.Sprintf("duration %.1fs is below preview threshold of %.0fs", duration.Seconds(), previewMaxDuration.Seconds()),
		}
	}

	return ValidationResult{IsValid: true, Duration: duration}
}

func getFLACDuration(filePath string) (time.Duration, error) {
	f, err := flac.ParseFile(filePath)
	if err != nil {
		return 0, err
	}
	defer f.Close()

	si, err := f.GetStreamInfo()
	if err != nil {
		return 0, err
	}

	if si.SampleRate <= 0 || si.SampleCount <= 0 {
		return 0, fmt.Errorf("invalid stream info: sampleRate=%d, totalSamples=%d", si.SampleRate, si.SampleCount)
	}

	duration := time.Duration(float64(si.SampleCount)/float64(si.SampleRate)*float64(time.Second) + 0.5)
	return duration, nil
}
