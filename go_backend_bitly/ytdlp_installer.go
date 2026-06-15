package gobackend

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"
)

var customYtDlpPath string

// SetCustomYtDlpPath permite establecer una ruta personalizada desde fuera (ej. Android)
func SetCustomYtDlpPath(path string) {
	customYtDlpPath = path
}

// GetYtDlpPath devuelve la ruta donde deberia estar el binario
func GetYtDlpPath() string {
	if customYtDlpPath != "" {
		return customYtDlpPath
	}
	// 1. Intentar encontrarlo en el PATH del sistema
	if p, err := exec.LookPath("yt-dlp"); err == nil {
		return p
	}
	if runtime.GOOS == "windows" {
		if p, err := exec.LookPath("yt-dlp.exe"); err == nil {
			return p
		}
	}

	// 2. Si no, usar la ruta local al lado del ejecutable
	name := "yt-dlp"
	if runtime.GOOS == "windows" {
		name = "yt-dlp.exe"
	}

	exe, _ := os.Executable()
	localPath := filepath.Join(filepath.Dir(exe), name)
	return localPath
}

// ytDlpDownloadName returns the platform-specific binary name for yt-dlp.
// On Android it uses the static Linux builds which are fully self-contained.
func ytDlpDownloadName() string {
	switch runtime.GOOS {
	case "windows":
		return "yt-dlp.exe"
	case "darwin":
		return "yt-dlp_macos"
	case "android":
		// Android uses the Linux static builds
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
	default:
		// Linux and other Unix-like
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

// EnsureYtDlp verifica y descarga yt-dlp si es necesario
func EnsureYtDlp() error {
	path := GetYtDlpPath()

	// 1. Verificar si ya existe en el sistema (PATH) o localmente
	if _, err := exec.LookPath("yt-dlp"); err == nil {
		return nil
	}
	if runtime.GOOS == "windows" {
		if _, err := exec.LookPath("yt-dlp.exe"); err == nil {
			return nil
		}
	}

	// 2. Verificar si existe localmente
	if _, err := os.Stat(path); err == nil {
		return nil
	}

	// 3. Descargar segun la plataforma
	downloadName := ytDlpDownloadName()
	url := "https://github.com/yt-dlp/yt-dlp/releases/latest/download/" + downloadName

	LogInfo("YouTube", "Downloading yt-dlp from %s...", url)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return fmt.Errorf("failed to download yt-dlp: %w", err)
	}
	defer resp.Body.Close()

	out, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("failed to create file %s: %w", path, err)
	}

	_, err = io.Copy(out, resp.Body)
	out.Close()
	if err != nil {
		return fmt.Errorf("failed to save yt-dlp: %w", err)
	}

	// 4. Dar permisos de ejecución (importante en Linux/Android)
	if runtime.GOOS != "windows" {
		os.Chmod(path, 0755)
	}

	LogInfo("YouTube", "yt-dlp installed successfully at: %s", path)
	return nil
}

// Export para que Flutter pueda iniciarlo
func EnsureYtDlpJSON() (string, error) {
	err := EnsureYtDlp()
	if err != nil {
		return "", err
	}
	return "ok", nil
}
