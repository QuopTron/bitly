package video

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/utils"
)

// Strategy handles YouTube video downloads via yt-dlp.
type Strategy struct {
	ytdlpPath string
	timeout   time.Duration
}

// VideoRequest represents a video download request.
type VideoRequest struct {
	TrackName string `json:"track_name"`
	Artist    string `json:"artist"`
	OutputDir string `json:"output_dir"`
	Format    string `json:"format"`
}

// VideoResult represents the result of a video download.
type VideoResult struct {
	FilePath string `json:"file_path"`
	Size     int64  `json:"size"`
}

// NewStrategy creates a new video download strategy.
func NewStrategy(ytdlpPath string, timeout time.Duration) *Strategy {
	if timeout <= 0 {
		timeout = 5 * time.Minute
	}
	return &Strategy{
		ytdlpPath: ytdlpPath,
		timeout:   timeout,
	}
}

// Download downloads a video for a track using yt-dlp.
// Searches YouTube for the track and downloads the best available stream <=720p.
func (s *Strategy) Download(ctx context.Context, req VideoRequest) (*VideoResult, error) {
	if s.ytdlpPath == "" {
		return nil, fmt.Errorf("video: yt-dlp not configured")
	}

	// Ensure output directory exists
	if err := os.MkdirAll(req.OutputDir, 0755); err != nil {
		return nil, fmt.Errorf("video: mkdir %s: %w", req.OutputDir, err)
	}

	// Build safe filenames
	safeArtist := utils.SanitizeFilename(req.Artist)
	safeTrack := utils.SanitizeFilename(req.TrackName)
	outputTemplate := filepath.Join(req.OutputDir, fmt.Sprintf("%s - %s.%%(ext)s", safeArtist, safeTrack))
	query := fmt.Sprintf("%s - %s", req.Artist, req.TrackName)

	ctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()

	// Format selection: prefer mp4, fallback to webm
	format := "best[height<=720]"
	if req.Format != "" {
		format = req.Format
	}

	cmd := exec.CommandContext(ctx, s.ytdlpPath,
		"--default-search", "ytsearch",
		"-f", format,
		"-o", outputTemplate,
		"--no-playlist",
		"--no-warnings",
		"--ignore-errors",
		"--print", "filename",
		query,
	)

	output, err := cmd.Output()
	if err != nil {
		if ctx.Err() != nil {
			return nil, fmt.Errorf("video: yt-dlp timed out after %v", s.timeout)
		}
		return nil, fmt.Errorf("video: yt-dlp search failed: %w", err)
	}

	// yt-dlp --print filename outputs the actual file path
	actualPath := strings.TrimSpace(string(output))
	if actualPath == "" {
		return nil, fmt.Errorf("video: yt-dlp returned empty filename")
	}

	// If path isn't absolute, prepend output dir
	if !filepath.IsAbs(actualPath) {
		actualPath = filepath.Join(req.OutputDir, actualPath)
	}

	// Verify the file was actually created
	info, err := os.Stat(actualPath)
	if err != nil {
		// Try to find the file by glob pattern
		matches, _ := filepath.Glob(filepath.Join(req.OutputDir, fmt.Sprintf("%s - %s*", safeArtist, safeTrack)))
		if len(matches) > 0 {
			actualPath = matches[0]
			info, err = os.Stat(actualPath)
		}
	}
	if err != nil {
		return nil, fmt.Errorf("video: output file not found after download")
	}

	return &VideoResult{
		FilePath: actualPath,
		Size:     info.Size(),
	}, nil
}
