package youtube

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"time"
)

func EnsureYtDlp() error {
	path := YtDlpPath()

	if _, err := exec.LookPath("yt-dlp"); err == nil {
		return nil
	}
	if runtime.GOOS == "windows" {
		if _, err := exec.LookPath("yt-dlp.exe"); err == nil {
			return nil
		}
	}

	if _, err := os.Stat(path); err == nil {
		return nil
	}

	downloadName := ytDlpDownloadName()
	url := "https://github.com/yt-dlp/yt-dlp/releases/latest/download/" + downloadName

	fmt.Printf("[YouTube] Downloading yt-dlp from %s...\n", url)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return fmt.Errorf("failed to download yt-dlp: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download failed: HTTP %d", resp.StatusCode)
	}

	out, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("failed to create file %s: %w", path, err)
	}

	_, err = io.Copy(out, resp.Body)
	out.Close()
	if err != nil {
		os.Remove(path)
		return fmt.Errorf("failed to save yt-dlp: %w", err)
	}

	if runtime.GOOS != "windows" {
		os.Chmod(path, 0755)
	}

	fmt.Printf("[YouTube] yt-dlp installed successfully at: %s\n", path)
	return nil
}

func EnsureYtDlpJSON() (string, error) {
	err := EnsureYtDlp()
	if err != nil {
		return "", err
	}
	return "ok", nil
}
