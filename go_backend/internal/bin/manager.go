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

// YTDLPPath returns the path only if the binary currently exists and looks
// valid (not a corrupted download such as an HTML 404 page), else "".
func (m *Manager) YTDLPPath() string {
	p := m.ResolvedYTDLPPath()
	if !isBinaryValid(p) {
		return ""
	}
	return p
}

// isBinaryValid checks whether a file at [path] looks like a real binary
// (not an HTML error page saved as a 404 response).  On ELF platforms
// (Android, Linux) it checks the ELF magic; on macOS the Mach-O magic;
// on Windows the PE header.  Files smaller than 100KB are also rejected
// (yt-dlp is ~40MB on Android, ffmpeg ~60MB).  If any read fails the
// binary is assumed valid (let the caller handle exec errors).
func isBinaryValid(path string) bool {
	fi, err := os.Stat(path)
	if err != nil {
		return false
	}
	if fi.Size() < 100_000 {
		return false // too small to be a real binary
	}
	f, err := os.Open(path)
	if err != nil {
		return true // can't read — assume valid
	}
	defer f.Close()
	buf := make([]byte, 16)
	if _, err := f.ReadAt(buf, 0); err != nil {
		return true
	}
	switch runtime.GOOS {
	case "android", "linux":
		// ELF magic: 0x7f 'E' 'L' 'F'
		return buf[0] == 0x7f && buf[1] == 'E' && buf[2] == 'L' && buf[3] == 'F'
	case "darwin":
		// Mach-O magic: 0xFE 0xED 0xFA (32-bit) or 0xFE 0xED 0xFA 0xCE/0xCF (64-bit)
		if buf[0] == 0xFE && buf[1] == 0xED && buf[2] == 0xFA {
			return true
		}
		// Universal binary: 0xCA 0xFE 0xBA 0xBE
		return buf[0] == 0xCA && buf[1] == 0xFE && buf[2] == 0xBA && buf[3] == 0xBE
	case "windows":
		// PE header: 'M' 'Z' (MZ)
		return buf[0] == 'M' && buf[1] == 'Z'
	default:
		return true
	}
}

// EnsureYTDLP downloads yt-dlp for the current platform if not present or
// if the existing binary looks corrupt (e.g. an HTML error page saved as a
// 404 response — the android-builds repo is sometimes down).
func (m *Manager) EnsureYTDLP() (*Binary, error) {
	binPath := filepath.Join(m.binDir, "yt-dlp"+exeSuffix())
	if isBinaryValid(binPath) {
		return &Binary{Name: "yt-dlp", Path: binPath, Platform: Platform()}, nil
	}
	// If a corrupt file exists, remove it before downloading.
	os.Remove(binPath)
	url := ytdlpDownloadURL()
	if url == "" {
		return nil, fmt.Errorf("bin: no yt-dlp binary for %s/%s", runtime.GOOS, runtime.GOARCH)
	}
	if err := m.download(url, binPath, 0755); err != nil {
		return nil, err
	}
	// Verify the download is a real binary; if not, remove and fail.
	if !isBinaryValid(binPath) {
		os.Remove(binPath)
		return nil, fmt.Errorf("bin: downloaded yt-dlp is not a valid binary (likely a 404 HTML page) from %s", url)
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
