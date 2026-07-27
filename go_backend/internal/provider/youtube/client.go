// Package youtube implements a YouTube Music client using yt-dlp.
// Requires the yt-dlp binary in PATH or configured path.
package youtube

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Client wraps yt-dlp for YouTube Music search and download.
type Client struct {
	ytdlpPath string
}

// NewClient creates a YouTube client using the yt-dlp binary.
// Pass empty string to auto-detect from PATH.
func NewClient(ytdlpPath string) *Client {
	if ytdlpPath == "" {
		ytdlpPath = "yt-dlp"
	}
	return &Client{ytdlpPath: ytdlpPath}
}

// Name returns "youtube" for the provider registry.
func (c *Client) Name() string { return "youtube" }

// searchResult represents a yt-dlp JSON search result.
type searchResult struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Duration  int    `json:"duration"`
	Channel   string `json:"channel"`
	ChannelID string `json:"channel_id"`
	Thumbnail string `json:"thumbnail"`
	URL       string `json:"url"`
}

// SearchTracks searches YouTube Music for tracks using yt-dlp.
func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	if limit < 1 || limit > 100 {
		limit = 10
	}
	searchQuery := fmt.Sprintf("ytsearch%d:%s", limit, query)
	args := []string{
		"--dump-json", "--no-warnings", "--flat-playlist",
		"--extract-flat", "--skip-download",
		searchQuery,
	}
	cmd := exec.Command(c.ytdlpPath, args...)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("youtube: yt-dlp search failed: %w", err)
	}

	results := make([]provider.TrackResult, 0)
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}
		var sr searchResult
		if err := json.Unmarshal([]byte(line), &sr); err != nil {
			continue
		}
		results = append(results, provider.TrackResult{
			ID:       "yt:" + sr.ID,
			Title:    sr.Title,
			Artist:   sr.Channel,
			Duration: sr.Duration,
			CoverURL: sr.Thumbnail,
			Provider: "youtube",
		})
	}
	return results, nil
}
