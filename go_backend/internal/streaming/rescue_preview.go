// ─────────────────────────────────────────────────────────────
// rescue_preview.go — Guard de PREVIEWS del stream: una fuente puede
// devolver una URL reproducible que en realidad es un clip de ~30s
// (los espejos con cuentas gratis degradan a sample, y Archive tiene
// ítems que son fragmentos). Antes eso se aceptaba como "stream ok" y
// la canción se cortaba a los 30 segundos.
//
// Dos controles, del más barato al más caro:
//   1) MARCADORES en la URL (sample / preview / 30s): gratis.
//   2) TAMAÑO real del archivo pedido con Range contra el tamaño que
//      DEBERÍA tener según la duración del catálogo. Un clip mide una
//      fracción; ahí se rechaza.
// El segundo solo corre en fuentes que se sabe que pueden devolver
// clips y solo si hay duración conocida: nunca agrega latencia a
// YouTube/ytmusic (que jamás sirven clips).
// Se conecta con: stream_package_fallback.go (rechaza el candidato y
// deja que la descarga real sirva la canción completa).
// Parte del flujo: reproducción (resolución de stream).
// ─────────────────────────────────────────────────────────────

package streaming

import (
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// fuentesConPreview son las fuentes que PUEDEN entregar un clip: espejos
// sin cuentas de pago, Archive (ítems de muestra) y SoundCloud (previews
// de tracks con copyright). youtube/ytmusic/deezer quedan afuera a
// propósito: sondearlas costaría una petición por reproducción sin
// ningún caso real que detectar.
var fuentesConPreview = map[string]bool{
	"flac-rescue":     true,
	"internetarchive": true,
	"soundcloud":      true,
	"qobuz-web":       true,
	"tidal-web":       true,
	"amazon-web":      true,
	"apple-music":     true,
}

// marcadoresPreview delatan un clip en la propia URL.
var marcadoresPreview = []string{
	"/sample", "sample/", "sample?", "sample_", "_sample",
	"preview", "_preview", "/30s", "_30s", "30sec", "clip30",
}

// fraccionTamanoPreview: un archivo que mide menos de esta fracción de lo
// que la canción debería pesar es un clip, no la canción.
const fraccionTamanoPreview = 0.45

// EsURIPreview reporta si la URL se delata como clip. No hace red.
func EsURIPreview(u string) bool {
	if u == "" {
		return false
	}
	minuscula := strings.ToLower(u)
	for _, marca := range marcadoresPreview {
		if strings.Contains(minuscula, marca) {
			return true
		}
	}
	return false
}

// bytesPorMsPorCalidad es el peso aproximado de cada milisegundo de audio.
// Se queda en el borde BAJO del rango real a propósito: el guard solo debe
// rechazar cuando hay evidencia clara, nunca una canción legítima (un
// falso positivo aquí haría descargar de más sin motivo).
func bytesPorMsPorCalidad(quality string) int64 {
	switch {
	case strings.Contains(strings.ToUpper(quality), "128"),
		strings.Contains(strings.ToUpper(quality), "LOW"):
		return 16 // MP3 128 kbps
	case strings.Contains(strings.ToUpper(quality), "320"),
		strings.Contains(strings.ToUpper(quality), "HIGH"):
		return 30 // MP3 320 kbps
	default:
		return 70 // FLAC/lossless (~560 kbps de piso)
	}
}

// tamanoEsperadoBytes es lo que debería pesar la canción completa.
func tamanoEsperadoBytes(duracionMs int, quality string) int64 {
	if duracionMs <= 0 {
		return 0
	}
	return int64(duracionMs) * bytesPorMsPorCalidad(quality)
}

// tamanoRemotoBytes pregunta SOLO por el tamaño total (Range de un byte).
// Devuelve 0 cuando no se puede saber (sin Content-Range, error, timeout):
// en ese caso no se juzga y el candidato pasa.
func tamanoRemotoBytes(u string) int64 {
	req, err := http.NewRequest(http.MethodGet, u, nil)
	if err != nil {
		return 0
	}
	req.Header.Set("Range", "bytes=0-0")
	req.Header.Set("User-Agent", "Mozilla/5.0")
	cliente := &http.Client{Timeout: 2 * time.Second}
	resp, err := cliente.Do(req)
	if err != nil {
		return 0
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 1))
	if cr := resp.Header.Get("Content-Range"); cr != "" {
		if i := strings.LastIndex(cr, "/"); i >= 0 {
			if n, err := strconv.ParseInt(strings.TrimSpace(cr[i+1:]), 10, 64); err == nil && n > 0 {
				return n
			}
		}
	}
	if n, err := strconv.ParseInt(resp.Header.Get("Content-Length"), 10, 64); err == nil && n > 0 {
		return n
	}
	return 0
}

// EsPreviewStream decide si [u] es un clip en vez de la canción pedida.
// [fuente] es el nombre del proveedor que la resolvió; [duracionMs] la
// duración del catálogo (0 = desconocida).
func EsPreviewStream(u, fuente string, duracionMs int, quality string) bool {
	if u == "" {
		return false
	}
	if EsURIPreview(u) {
		return true
	}
	if !fuentesConPreview[fuente] || duracionMs < 60000 {
		return false
	}
	esperado := tamanoEsperadoBytes(duracionMs, quality)
	if esperado <= 0 {
		return false
	}
	real := tamanoRemotoBytes(u)
	if real <= 0 {
		return false
	}
	return float64(real) < float64(esperado)*fraccionTamanoPreview
}
