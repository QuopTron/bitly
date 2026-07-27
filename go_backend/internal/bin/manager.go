// Package bin manages downloading and updating external binaries
// (yt-dlp, FFmpeg, FFprobe) for all platforms and architectures.
package bin

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"time"
)

// Binary describes an external binary with platform info.
type Binary struct {
	Name     string `json:"name"`
	Version  string `json:"version"`
	Path     string `json:"path"`
	URL      string `json:"url"`
	Platform string `json:"platform"`
}

// Manager handles binary downloads with architecture detection.
type Manager struct {
	binDir string
	http   *http.Client
}

// NewManager creates a binary manager in the given directory.
func NewManager(binDir string) *Manager {
	return &Manager{
		binDir: binDir,
		http:   &http.Client{Timeout: 10 * time.Minute},
	}
}

// Platform returns OS/ARCH string for downloads.
func Platform() string {
	return runtime.GOOS + "_" + runtime.GOARCH
}

// EnsureYTDLP downloads yt-dlp for the current platform if not present.
func (m *Manager) EnsureYTDLP() (*Binary, error) {
	binPath := filepath.Join(m.binDir, "yt-dlp"+exeSuffix())
	if _, err := os.Stat(binPath); err == nil {
		return &Binary{Name: "yt-dlp", Path: binPath, Platform: Platform()}, nil
	}

	url := ytdlpDownloadURL()
	if url == "" {
		return nil, fmt.Errorf("bin: no yt-dlp binary for %s/%s", runtime.GOOS, runtime.GOARCH)
	}

	if err := m.download(url, binPath, 0755); err != nil {
		return nil, err
	}
	return &Binary{Name: "yt-dlp", Path: binPath, URL: url, Platform: Platform()}, nil
}

// EnsureFFmpeg downloads FFmpeg for the current platform if not present.
func (m *Manager) EnsureFFmpeg() (*Binary, error) {
	binPath := filepath.Join(m.binDir, "ffmpeg"+exeSuffix())
	if _, err := os.Stat(binPath); err == nil {
		return &Binary{Name: "ffmpeg", Path: binPath, Platform: Platform()}, nil
	}

	url := ffmpegDownloadURL()
	if url == "" {
		return nil, fmt.Errorf("bin: ffmpeg must be installed manually for %s/%s.\n"+
			"Download from: https://ffmpeg.org/download.html", runtime.GOOS, runtime.GOARCH)
	}

	if err := m.download(url, binPath, 0755); err != nil {
		return nil, err
	}
	return &Binary{Name: "ffmpeg", Path: binPath, URL: url, Platform: Platform()}, nil
}

// EnsureFFprobe ensures ffprobe is available alongside FFmpeg.
func (m *Manager) EnsureFFprobe() (*Binary, error) {
	binPath := filepath.Join(m.binDir, "ffprobe"+exeSuffix())
	if _, err := os.Stat(binPath); err == nil {
		return &Binary{Name: "ffprobe", Path: binPath, Platform: Platform()}, nil
	}

	// ffprobe usually comes with ffmpeg
	ffmpegBin := filepath.Join(m.binDir, "ffmpeg"+exeSuffix())
	if _, err := os.Stat(ffmpegBin); err == nil {
		return nil, fmt.Errorf("bin: ffprobe not found alongside ffmpeg")
	}
	return nil, fmt.Errorf("bin: ffprobe not found")
}

func exeSuffix() string {
	if runtime.GOOS == "windows" {
		return ".exe"
	}
	return ""
}

func ytdlpDownloadURL() string {
	base := "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
	switch runtime.GOOS {
	case "windows":
		return base + ".exe"
	case "darwin":
		switch runtime.GOARCH {
		case "arm64":
			return base + "_macos_arm64"
		default:
			return base + "_macos"
		}
	case "linux":
		switch runtime.GOARCH {
		case "arm64":
			return base + "_linux_aarch64"
		case "arm":
			return base + "_linux_arm"
		default:
			return base + "_linux"
		}
	default:
		return ""
	}
}

func ffmpegDownloadURL() string {
	// FFmpeg doesn't have a simple single-binary URL scheme.
	// Users should download from https://ffmpeg.org/download.html or use:
	//   Windows: choco install ffmpeg
	//   macOS:   brew install ffmpeg
	//   Linux:   apt install ffmpeg  (or pacman, dnf, etc.)
	return ""
}

func (m *Manager) download(url, dest string, mode os.FileMode) error {
	resp, err := m.http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if err := os.MkdirAll(filepath.Dir(dest), 0755); err != nil {
		return err
	}

	out, err := os.CreateTemp(filepath.Dir(dest), "download-*")
	if err != nil {
		return err
	}
	tmpPath := out.Name()

	if _, err := io.Copy(out, resp.Body); err != nil {
		out.Close()
		os.Remove(tmpPath)
		return err
	}
	out.Close()

	if err := os.Chmod(tmpPath, mode); err != nil {
		os.Remove(tmpPath)
		return err
	}

	return os.Rename(tmpPath, dest)
}
