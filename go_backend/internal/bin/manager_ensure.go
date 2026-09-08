package bin

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
)

// EnsureYTDLP descarga yt-dlp para la plataforma actual si falta o está corrupto.
func (m *Manager) EnsureYTDLP() (*Binary, error) {
	rutaBin := filepath.Join(m.dirBin, "yt-dlp"+sufijoExe())
	if esBinarioValido(rutaBin) {
		return &Binary{Name: "yt-dlp", Path: rutaBin, Platform: Platform()}, nil
	}
	// Si existe un archivo corrupto, se elimina antes de descargar.
	os.Remove(rutaBin)
	urlDescarga := urlDescargaYtDLP()
	if urlDescarga == "" {
		return nil, fmt.Errorf("ERR_BIN_NO_YTDLP: no hay binario yt-dlp para %s/%s", runtime.GOOS, runtime.GOARCH)
	}
	if err := m.descargar(urlDescarga, rutaBin, 0755); err != nil {
		return nil, err
	}
	// Verifica que lo descargado sea un binario real; si no, lo borra y falla.
	if !esBinarioValido(rutaBin) {
		os.Remove(rutaBin)
		return nil, fmt.Errorf("ERR_BIN_YTDLP_INVALIDO: el yt-dlp descargado no es un binario válido (probablemente una página 404 HTML) desde %s", urlDescarga)
	}
	return &Binary{Name: "yt-dlp", Path: rutaBin, URL: urlDescarga, Platform: Platform()}, nil
}

// EnsureFFmpeg descarga FFmpeg para la plataforma actual si falta.
func (m *Manager) EnsureFFmpeg() (*Binary, error) {
	rutaBin := filepath.Join(m.dirBin, "ffmpeg"+sufijoExe())
	if _, err := os.Stat(rutaBin); err == nil {
		return &Binary{Name: "ffmpeg", Path: rutaBin, Platform: Platform()}, nil
	}
	urlDescarga := urlDescargaFFmpeg()
	if urlDescarga == "" {
		return nil, fmt.Errorf("ERR_BIN_NO_FFMPEG: ffmpeg debe instalarse manualmente para %s/%s.\n"+
			"Descárgalo desde: https://ffmpeg.org/download.html", runtime.GOOS, runtime.GOARCH)
	}
	if err := m.descargar(urlDescarga, rutaBin, 0755); err != nil {
		return nil, err
	}
	return &Binary{Name: "ffmpeg", Path: rutaBin, URL: urlDescarga, Platform: Platform()}, nil
}

// EnsureFFprobe asegura que ffprobe exista junto a FFmpeg.
func (m *Manager) EnsureFFprobe() (*Binary, error) {
	rutaBin := filepath.Join(m.dirBin, "ffprobe"+sufijoExe())
	if _, err := os.Stat(rutaBin); err == nil {
		return &Binary{Name: "ffprobe", Path: rutaBin, Platform: Platform()}, nil
	}
	binFFmpeg := filepath.Join(m.dirBin, "ffmpeg"+sufijoExe())
	if _, err := os.Stat(binFFmpeg); err == nil {
		return nil, fmt.Errorf("ERR_BIN_NO_FFPROBE: no se encontró ffprobe junto a ffmpeg")
	}
	return nil, fmt.Errorf("ERR_BIN_NO_FFPROBE: no se encontró ffprobe")
}
