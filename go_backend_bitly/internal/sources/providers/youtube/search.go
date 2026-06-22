package youtube

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func (c *Client) SearchYouTubeVideo(trackName, artistName string) (string, error) {
	fmt.Printf("[YTSearch] Searching for: %s - %s\n", artistName, trackName)

	if err := EnsureYtDlp(); err != nil {
		fmt.Printf("[YTSearch] Failed to ensure yt-dlp: %v, falling back to InnerTube\n", err)
		return c.searchInnerTube(trackName, artistName)
	}

	url, err := c.searchWithYtDlp(trackName, artistName)
	if err == nil && url != "" {
		fmt.Printf("[YTSearch] yt-dlp found stream\n")
		return url, nil
	}
	if err != nil {
		fmt.Printf("[YTSearch] yt-dlp failed: %v, falling back to InnerTube\n", err)
	} else {
		fmt.Printf("[YTSearch] yt-dlp returned empty, falling back to InnerTube\n")
	}

	return c.searchInnerTube(trackName, artistName)
}

func (c *Client) searchWithYtDlp(trackName, artistName string) (string, error) {
	query := artistName + " " + trackName
	ytPath := c.getYtDlpPath()

	if fi, err := os.Stat(ytPath); err != nil {
		return "", fmt.Errorf("yt-dlp not found at %s: %w", ytPath, err)
	} else {
		fmt.Printf("[YTSearch] yt-dlp exists: size=%d\n", fi.Size())
	}

	ctx, cancel := context.WithTimeout(context.Background(), ytDlpSearchTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, ytPath,
		"--default-search", "ytsearch",
		"-f", "best[height<=720]",
		"-g",
		"--no-playlist",
		"--no-warnings",
		"--ignore-errors",
		query,
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		if ctx.Err() != nil {
			return "", fmt.Errorf("yt-dlp search timed out after %v", ytDlpSearchTimeout)
		}
		outStr := strings.TrimSpace(string(out))
		if outStr != "" {
			parts := strings.Split(outStr, "\n")
			for _, p := range parts {
				p = strings.TrimSpace(p)
				if strings.HasPrefix(p, "http://") || strings.HasPrefix(p, "https://") {
					return p, nil
				}
			}
		}
		return "", err
	}

	url := strings.TrimSpace(string(out))
	if url == "" {
		return "", fmt.Errorf("yt-dlp returned empty result")
	}
	return strings.Split(url, "\n")[0], nil
}
