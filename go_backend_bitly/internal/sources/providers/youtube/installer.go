package youtube

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sync"
)

var customYtDlpPath string
var customMu sync.RWMutex

func SetCustomYtDlpPath(path string) {
	customMu.Lock()
	customYtDlpPath = path
	customMu.Unlock()
}

func YtDlpPath() string {
	customMu.RLock()
	if customYtDlpPath != "" {
		customMu.RUnlock()
		return customYtDlpPath
	}
	customMu.RUnlock()

	if p, err := exec.LookPath("yt-dlp"); err == nil {
		return p
	}
	if runtime.GOOS == "windows" {
		if p, err := exec.LookPath("yt-dlp.exe"); err == nil {
			return p
		}
	}

	name := "yt-dlp"
	if runtime.GOOS == "windows" {
		name = "yt-dlp.exe"
	}
	exe, err := os.Executable()
	if err != nil {
		return name
	}
	return filepath.Join(filepath.Dir(exe), name)
}

func ytDlpDownloadName() string {
	switch runtime.GOOS {
	case "windows":
		return "yt-dlp.exe"
	case "darwin":
		return "yt-dlp_macos"
	default:
		switch runtime.GOARCH {
		case "arm64":
			return "yt-dlp_linux_aarch64"
		case "amd64":
			return "yt-dlp_linux"
		case "386":
			return "yt-dlp_linux_x86"
		case "arm":
			return "yt-dlp_linux_armv7l"
		default:
			return "yt-dlp_linux"
		}
	}
}
