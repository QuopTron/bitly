package bin

import (
	"fmt"
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

// ResolvedYTDLPPath returns the path where yt-dlp will be (or is) installed,
// even if it hasn't been downloaded yet. Callers use this to configure the
// YouTube client; the binary is ensured asynchronously.
func (m *Manager) ResolvedYTDLPPath() string {
	return filepath.Join(m.binDir, "yt-dlp"+exeSuffix())
}

// YTDLPPath returns the path only if the binary currently exists, else "".
func (m *Manager) YTDLPPath() string {
	p := m.ResolvedYTDLPPath()
	if _, err := os.Stat(p); err != nil {
		return ""
	}
	return p
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
	ffmpegBin := filepath.Join(m.binDir, "ffmpeg"+exeSuffix())
	if _, err := os.Stat(ffmpegBin); err == nil {
		return nil, fmt.Errorf("bin: ffprobe not found alongside ffmpeg")
	}
	return nil, fmt.Errorf("bin: ffprobe not found")
}
