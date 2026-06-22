package lyrics

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/utils"
)

// Strategy handles lyrics saving and format detection.
type Strategy struct{}

// LyricsRequest represents a lyrics fetch request.
type LyricsRequest struct {
	TrackID    string `json:"track_id"`
	TrackName  string `json:"track_name"`
	ArtistName string `json:"artist_name"`
	OutputDir  string `json:"output_dir"`
}

// LyricsResult represents the result of a lyrics download.
type LyricsResult struct {
	FilePath string `json:"file_path"`
	Format   string `json:"format"` // "lrc" or "txt"
}

// NewStrategy creates a new lyrics download strategy.
func NewStrategy() *Strategy {
	return &Strategy{}
}

// SaveLyrics saves lyrics text, auto-detecting LRC format from content.
func (s *Strategy) SaveLyrics(ctx context.Context, req LyricsRequest, lyricsText string) (*LyricsResult, error) {
	if lyricsText == "" {
		return nil, fmt.Errorf("lyrics: no lyrics to save")
	}

	format := detectLyricsFormat(lyricsText)
	var ext string
	if format == "lrc" {
		ext = ".lrc"
	} else {
		ext = ".txt"
	}

	filePath, err := s.writeLyrics(req, lyricsText, ext)
	if err != nil {
		return nil, err
	}
	return &LyricsResult{FilePath: filePath, Format: format}, nil
}

// SavePlainLyrics saves lyrics as plain text (no LRC timestamps).
func (s *Strategy) SavePlainLyrics(ctx context.Context, req LyricsRequest, lyricsText string) (*LyricsResult, error) {
	if lyricsText == "" {
		return nil, fmt.Errorf("lyrics: no lyrics to save")
	}

	filePath, err := s.writeLyrics(req, lyricsText, ".txt")
	if err != nil {
		return nil, err
	}
	return &LyricsResult{FilePath: filePath, Format: "txt"}, nil
}

func (s *Strategy) writeLyrics(req LyricsRequest, lyricsText, ext string) (string, error) {
	if err := os.MkdirAll(req.OutputDir, 0755); err != nil {
		return "", fmt.Errorf("lyrics: mkdir %s: %w", req.OutputDir, err)
	}

	safeArtist := utils.SanitizeFilename(req.ArtistName)
	safeTrack := utils.SanitizeFilename(req.TrackName)
	filename := fmt.Sprintf("%s - %s%s", safeArtist, safeTrack, ext)

	// Check for duplicates: if track ID provided, prefer hash-based naming
	if req.TrackID != "" {
		hash := fmt.Sprintf("%x", utils.HashString(req.TrackID))
		filename = fmt.Sprintf("lyrics_%s%s", hash, ext)
	}

	filePath := filepath.Join(req.OutputDir, filename)
	if err := os.WriteFile(filePath, []byte(lyricsText), 0644); err != nil {
		return "", fmt.Errorf("lyrics: write file: %w", err)
	}

	return filePath, nil
}

// detectLyricsFormat detects whether lyrics content is LRC (timestamped) or plain text.
func detectLyricsFormat(content string) string {
	lines := strings.Split(content, "\n")
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}
		// LRC format: [mm:ss.xx] or [mm:ss] text
		if len(trimmed) > 4 && trimmed[0] == '[' {
			// Check for timestamp pattern: [00: or [0: or [mm:ss.xx]
			closeBracket := strings.IndexByte(trimmed, ']')
			if closeBracket > 1 && closeBracket < 10 {
				timePart := trimmed[1:closeBracket]
				if strings.Contains(timePart, ":") {
					return "lrc"
				}
			}
		}
	}
	return "txt"
}
