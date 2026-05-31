package gobackend

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
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

// EnsureYtDlp verifica y descarga yt-dlp si es necesario
func EnsureYtDlp() error {
	// On Android, yt-dlp Python binary won't work (no Python interpreter).
	// The android_youtube.go uses native Go YouTube client instead.
	if runtime.GOOS == "android" {
		return nil
	}

	path := GetYtDlpPath()

	// 1. Verificar si ya existe en el sistema (PATH)
	if _, err := exec.LookPath("yt-dlp"); err == nil {
		return nil
	}
	if runtime.GOOS == "windows" {
		if _, err := exec.LookPath("yt-dlp.exe"); err == nil {
			return nil
		}
	}

	// 2. Verificar si existe localmente en la carpeta del backend
	if _, err := os.Stat(path); err == nil {
		return nil
	}

	// 3. Descargar segun la plataforma
	url := "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
	if runtime.GOOS == "windows" {
		url += ".exe"
	}

	fmt.Printf("[YouTube] Downloading yt-dlp from %s...\n", url)

	resp, err := http.Get(url)
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

	fmt.Println("[YouTube] yt-dlp installed successfully at:", path)
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
