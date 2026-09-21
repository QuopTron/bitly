package gobackend

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Descarga de carátulas: se separa de SaveCover para poder probarla sola.
//
// Los CDN de portadas (i.scdn.co, e-cdn-images, m.media-amazon, lh3.google…)
// devuelven 403 a clientes sin User-Agent, y algunos contestan 200 con una
// página HTML de error. Sin la validación de imagen se guardaba ese HTML como
// .jpg y la carátula "aparecía" rota en la UI en vez de reintentarse.

// errPortadaNoEsImagen marca respuestas 200 que no son una imagen real.
var errPortadaNoEsImagen = errors.New("la respuesta no es una imagen")

// descargarImagenPortada baja la imagen de [url] y devuelve sus bytes.
// Falla con errPortadaNoEsImagen si el cuerpo no tiene firma de imagen.
func descargarImagenPortada(url string) ([]byte, error) {
	if !strings.HasPrefix(url, "http://") && !strings.HasPrefix(url, "https://") {
		return nil, fmt.Errorf("url inválida: %q", url)
	}
	client := &http.Client{Timeout: 15 * time.Second}
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgentPortadas)
	req.Header.Set("Referer", refererPortadas(url))
	req.Header.Set("Accept", "image/avif,image/webp,image/png,image/jpeg,*/*;q=0.8")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("status %d", resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, 8*1024*1024))
	if err != nil {
		return nil, err
	}
	if len(data) == 0 {
		return nil, errors.New("respuesta vacía")
	}
	if !esImagen(data) {
		return nil, errPortadaNoEsImagen
	}
	return data, nil
}

const userAgentPortadas = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
	"AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

// refererPortadas devuelve el Referer del sitio dueño del CDN: algunos
// espejos de portadas lo exigen y sin él contestan 403.
func refererPortadas(url string) string {
	switch {
	case strings.Contains(url, "scdn.co"), strings.Contains(url, "spotifycdn.com"):
		return "https://open.spotify.com/"
	case strings.Contains(url, "dzcdn.net"):
		return "https://www.deezer.com/"
	case strings.Contains(url, "media-amazon.com"), strings.Contains(url, "ssl-images-amazon.com"):
		return "https://music.amazon.com/"
	case strings.Contains(url, "googleusercontent.com"), strings.Contains(url, "ytimg.com"):
		return "https://music.youtube.com/"
	case strings.Contains(url, "mzstatic.com"):
		return "https://music.apple.com/"
	}
	return ""
}

// esImagen reconoce las firmas de los formatos de portada que se usan.
func esImagen(data []byte) bool {
	if len(data) < 12 {
		return false
	}
	switch {
	case data[0] == 0xFF && data[1] == 0xD8: // JPEG
		return true
	case string(data[0:8]) == "\x89PNG\r\n\x1a\n": // PNG
		return true
	case string(data[0:6]) == "GIF87a" || string(data[0:6]) == "GIF89a":
		return true
	case string(data[0:4]) == "RIFF" && string(data[8:12]) == "WEBP": // WEBP
		return true
	case string(data[4:12]) == "ftypavif" || string(data[4:8]) == "ftyp":
		return true
	}
	return false
}
