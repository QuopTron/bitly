package youtube

import (
	"fmt"
	"log"
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
//
// yt-dlp va primero: es local, no depende de nadie y no tiene cuota. Cuando
// falla (IP bloqueada, rate-limit, binario viejo) se intenta el respaldo por
// cobalt —ver cobalt.go—, que resuelve el mismo audio desde otra IP. El
// respaldo es opcional: sin instancia configurada no abre ninguna conexión.
func (c *Client) Download(videoID, outputDir, quality string) (*DownloadResult, error) {
	res, err := c.descargarConYtDlp(videoID, outputDir, quality)
	if err == nil {
		return res, nil
	}
	alterno, cerr := c.descargarConCobalt(videoID, outputDir)
	if cerr == nil {
		log.Printf("[youtube] yt-dlp falló (%v); el respaldo cobalt entregó %s", err, alterno.FilePath)
		return alterno, nil
	}
	// Con una instancia configurada, el motivo del respaldo se suma al
	// error: un fallo de la instancia propia no puede verse igual que
	// "yt-dlp no anda".
	if c.instanciaCobalt().activa() {
		return nil, fmt.Errorf("youtube: download failed: %w (respaldo cobalt: %v)", err, cerr)
	}
	return nil, fmt.Errorf("youtube: download failed: %w", err)
}

// descargarConYtDlp es la vía normal: bajar el audio con el binario local.
func (c *Client) descargarConYtDlp(videoID, outputDir, quality string) (*DownloadResult, error) {
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

	output, err := ejecutarYtDlp(c.ytdlpPath, args)
	if err != nil {
		return nil, fmt.Errorf("youtube: download failed: %w", err)
	}

	filePath := strings.TrimSpace(string(output))
	return &DownloadResult{
		FilePath: filePath,
	}, nil
}
