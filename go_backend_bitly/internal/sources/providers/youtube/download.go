package youtube

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

func (c *Client) DownloadYouTubeVideo(trackName, artistName, outputPath string) (string, error) {
	fmt.Printf("[YTDL] Downloading video: %s - %s\n", artistName, trackName)

	url, err := c.downloadWithYtDlp(trackName, artistName, outputPath)
	if err == nil && url != "" {
		return url, nil
	}
	if err != nil {
		fmt.Printf("[YTDL] yt-dlp download failed: %v, falling back to InnerTube stream\n", err)
	} else {
		fmt.Printf("[YTDL] yt-dlp returned empty, falling back to InnerTube stream\n")
	}

	streamURL, err := c.searchInnerTube(trackName, artistName)
	if err != nil {
		fmt.Printf("[YTDL] Search failed: %v\n", err)
		return "", err
	}
	fmt.Printf("[YTDL] Got stream URL, downloading to %s\n", outputPath)
	result, err := downloadFromStreamURL(streamURL, outputPath)
	if err != nil {
		fmt.Printf("[YTDL] Download failed: %v\n", err)
		return "", err
	}
	fmt.Printf("[YTDL] Download complete: %s\n", result)
	return result, nil
}

func (c *Client) downloadWithYtDlp(trackName, artistName, outputPath string) (string, error) {
	query := artistName + " " + trackName

	os.Remove(outputPath)

	ctx, cancel := context.WithTimeout(context.Background(), ytDlpDownloadTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, c.getYtDlpPath(),
		"--default-search", "ytsearch",
		"-f", "best[height<=720]",
		"-o", outputPath,
		"--no-playlist",
		"--no-warnings",
		"--ignore-errors",
		"--merge-output-format", "mp4",
		query,
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		if ctx.Err() != nil {
			return "", fmt.Errorf("yt-dlp download timed out after %v", ytDlpDownloadTimeout)
		}
		outStr := strings.TrimSpace(string(out))
		if outStr != "" {
			return "", fmt.Errorf("yt-dlp failed: %s", outStr)
		}
		return "", err
	}

	if _, statErr := os.Stat(outputPath); statErr == nil {
		return outputPath, nil
	}

	for _, ext := range []string{".mp4", ".webm", ".mkv"} {
		candidate := outputPath + ext
		if _, statErr := os.Stat(candidate); statErr == nil {
			return candidate, nil
		}
	}

	return outputPath, nil
}

func downloadFromStreamURL(streamURL, outputPath string) (string, error) {
	dlClient := &http.Client{
		Timeout: 5 * time.Minute,
		Transport: &http.Transport{
			DisableKeepAlives: true,
		},
	}
	defer dlClient.CloseIdleConnections()

	resp, err := dlClient.Get(streamURL)
	if err != nil {
		return "", fmt.Errorf("download request failed: %w", err)
	}
	defer resp.Body.Close()

	os.Remove(outputPath)
	out, err := os.Create(outputPath)
	if err != nil {
		return "", fmt.Errorf("failed to create output file: %w", err)
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to download: %w", err)
	}

	return outputPath, nil
}
