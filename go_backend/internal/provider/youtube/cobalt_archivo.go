// ─────────────────────────────────────────────────────────────
// cobalt_archivo.go — PART de cobalt.go: la bajada del archivo que la
// instancia entregó y el nombre con el que se guarda.
//
// Por qué el nombre se sanea: el nombre que sugiere la instancia es un dato de
// AFUERA, no una ruta. Solo se acepta si es un nombre plano (sin barras ni
// `..`); si no, se usa el id del video con la extensión del tipo de contenido.
// Así una instancia hostil no puede escribir fuera de la carpeta del usuario.
//
// Se conecta con: cobalt.go (misma package) + download.go.
// Parte del flujo: descarga (YouTube → segunda vía).
// ─────────────────────────────────────────────────────────────

package youtube

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// timeoutCobaltArchivo es el techo de la descarga del archivo: una canción de
// 10 MB tarda segundos, y el resto es holgura.
const timeoutCobaltArchivo = 5 * time.Minute

// bajarArchivo baja el enlace a la carpeta de destino y devuelve la ruta
// escrita.
func (instancia cobaltConfig) bajarArchivo(enlace, nombre, videoID, outputDir string) (string, error) {
	if err := os.MkdirAll(outputDir, 0o755); err != nil {
		return "", fmt.Errorf("cobalt: no se pudo preparar la carpeta: %w", err)
	}
	req, err := http.NewRequest(http.MethodGet, enlace, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", userAgent)
	cliente := &http.Client{Timeout: timeoutCobaltArchivo}
	resp, err := cliente.Do(req)
	if err != nil {
		return "", fmt.Errorf("cobalt: no se pudo bajar el archivo: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return "", fmt.Errorf("cobalt: el enlace respondió %d", resp.StatusCode)
	}
	destino := filepath.Join(
		outputDir,
		nombreSeguroCobalt(nombre, resp.Header.Get("Content-Type"), videoID),
	)
	archivo, err := os.Create(destino)
	if err != nil {
		return "", fmt.Errorf("cobalt: no se pudo escribir el archivo: %w", err)
	}
	if _, err := io.Copy(archivo, resp.Body); err != nil {
		archivo.Close()
		os.Remove(destino)
		return "", fmt.Errorf("cobalt: la descarga se cortó: %w", err)
	}
	if err := archivo.Close(); err != nil {
		return "", fmt.Errorf("cobalt: no se pudo cerrar el archivo: %w", err)
	}
	return destino, nil
}

// nombreSeguroCobalt arma el nombre del archivo: el que sugiere la instancia
// SOLO si es un nombre plano (sin barras ni `..`), y si no uno derivado del id
// y del tipo de contenido.
func nombreSeguroCobalt(nombre, contentType, videoID string) string {
	sugerido := strings.TrimSpace(nombre)
	if esNombrePlano(sugerido) {
		if limpiado := limpiarNombreCobalt(sugerido); limpiado != "" {
			return limpiado
		}
	}
	return strings.TrimSpace(videoID) + "." + extensionCobalt(contentType)
}

// esNombrePlano reporta si el nombre es un nombre de archivo y no una ruta
// (nada de separadores, ni `.`/`..`, ni nombres vacíos).
func esNombrePlano(nombre string) bool {
	if nombre == "" || nombre == "." || nombre == ".." {
		return false
	}
	if strings.ContainsAny(nombre, `/\`) {
		return false
	}
	return !strings.ContainsRune(nombre, os.PathSeparator)
}

// extensionCobalt deriva la extensión del archivo del tipo de contenido.
func extensionCobalt(contentType string) string {
	tipo := strings.ToLower(strings.TrimSpace(strings.Split(contentType, ";")[0]))
	switch tipo {
	case "audio/mpeg", "audio/mp3":
		return "mp3"
	case "audio/ogg", "application/ogg":
		return "opus"
	case "audio/wav", "audio/x-wav":
		return "wav"
	case "audio/flac", "audio/x-flac":
		return "flac"
	default:
		// YouTube entrega m4a (AAC) o webm/opus; m4a es el caso normal.
		return "m4a"
	}
}

// limpiarNombreCobalt saca caracteres de control del nombre y acota su largo.
func limpiarNombreCobalt(nombre string) string {
	limpio := strings.Map(func(r rune) rune {
		if r < 0x20 || r == 0x7f {
			return -1
		}
		return r
	}, nombre)
	limpio = strings.TrimSpace(limpio)
	if len(limpio) > 120 {
		limpio = strings.TrimSpace(limpio[:120])
	}
	return limpio
}
