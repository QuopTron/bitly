//go:build !android
// +build !android

package gobackend

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func SearchYouTubeVideo(trackName, artistName string) (string, error) {
	query := artistName + " " + trackName

	cmd := exec.Command(GetYtDlpPath(),
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
		return "", nil
	}
	return strings.Split(url, "\n")[0], nil
}

func DownloadYouTubeVideo(trackName, artistName, outputPath string) (string, error) {
	query := artistName + " " + trackName

	os.Remove(outputPath)

	cmd := exec.Command(GetYtDlpPath(),
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
