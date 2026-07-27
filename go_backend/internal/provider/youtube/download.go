package youtube

import (
	"fmt"
	"os/exec"
	"strings"
)

// DownloadResult holds the result of a YouTube download.
type DownloadResult struct {
	FilePath string `json:"filePath"`
	Title    string `json:"title"`
	Duration int    `json:"duration"`
}

// Download downloads audio from a YouTube video ID.
// quality options: "best", "128", "192", "256", "320" (kbps)
func (c *Client) Download(videoID, outputDir, quality string) (*DownloadResult, error) {
	url := fmt.Sprintf("https://www.youtube.com/watch?v=%s", videoID)

	format := "bestaudio/best"
	switch quality {
	case "128":
		format = "bestaudio[abr<=128]/bestaudio/best"
	case "192":
		format = "bestaudio[abr<=192]/bestaudio/best"
	case "256":
		format = "bestaudio[abr<=256]/bestaudio/best"
	case "320":
		format = "bestaudio[abr<=320]/bestaudio/best"
	}

	outputTemplate := outputDir + "/%(title)s.%(ext)s"
	args := []string{
		"-x", "--audio-format", "mp3",
		"--audio-quality", "0",
		"-f", format,
		"-o", outputTemplate,
		"--no-warnings",
		"--print", "filename",
		url,
	}

	cmd := exec.Command(c.ytdlpPath, args...)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("youtube: download failed: %w", err)
	}

	filePath := strings.TrimSpace(string(output))
	return &DownloadResult{
		FilePath: filePath,
	}, nil
}
