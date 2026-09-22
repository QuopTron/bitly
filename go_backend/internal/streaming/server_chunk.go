package streaming

import (
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// fetchChunk requests one bounded upstream range, retrying transient failures
// (network hiccups, momentary bot-gate 403s) a couple of times before giving
// up. Without this, a single failed mid-stream chunk closes the client
// connection and truncates the song at the last good chunk boundary (e.g.
// exactly 512KB in) — mpv then "completes" early and the app thinks the
// stream died.
func (s *Streamer) fetchChunk(audioURL string, from, tamano int64) (*http.Response, error) {
	if tamano <= 0 {
		tamano = streamChunkSize
	}
	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			time.Sleep(time.Duration(attempt) * 300 * time.Millisecond)
		}
		req, err := http.NewRequest("GET", audioURL, nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", from, from+tamano-1))
		req.Header.Set("User-Agent", youtubeMediaUA)
		resp, err := s.client.Do(req)
		if err != nil {
			lastErr = err
			continue
		}
		if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusPartialContent {
			body := make([]byte, 64)
			resp.Body.Read(body)
			resp.Body.Close()
			lastErr = fmt.Errorf("upstream %s returned %d (%.64s)", audioURL, resp.StatusCode, string(body))
			continue
		}
		return resp, nil
	}
	return nil, lastErr
}

// maxChunkSinRango es el techo de la respuesta cuando el llamador NO pidió un
// rango concreto (length <= 0). Sin esto, un origen que ignorara el Range y
// devolviera el archivo entero se metía completo en memoria.
const maxChunkSinRango = 16 << 20 // 16 MiB

// StreamChunk fetches a byte range of audio for mobile/AAR use.
func (s *Streamer) StreamChunk(audioURL string, offset, length int64) ([]byte, error) {
	req, err := http.NewRequest("GET", audioURL, nil)
	if err != nil {
		return nil, err
	}
	if offset >= 0 && length > 0 {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", offset, offset+length-1))
	} else if offset > 0 {
		// Sin longitud pero con offset: "desde acá en adelante". El techo de
		// lectura lo pone el tamaño de trozo configurado (ver abajo).
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-", offset))
	}
	req.Header.Set("User-Agent", httpclient.RandomUserAgent())

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusPartialContent {
		return nil, fmt.Errorf("stream: %s returned %d", audioURL, resp.StatusCode)
	}

	// Un 200 a una petición con rango significa que el origen IGNORÓ el Range y
	// está mandando el archivo desde el byte 0. Antes se leía todo y se devolvía
	// como si fuera el trozo pedido: memoria del tamaño del archivo entero (un
	// FLAC de 40 MB por llamada, y esto se llama durante toda la reproducción) y,
	// además, datos equivocados — el trozo arrancaba en 0 en vez de en `offset`.
	// Se avanza hasta el offset real descartando lo anterior.
	if resp.StatusCode == http.StatusOK && offset > 0 && length > 0 {
		descartado, err := io.CopyN(io.Discard, resp.Body, offset)
		if err != nil {
			return nil, fmt.Errorf("stream: saltando al offset %d: %w", offset, err)
		}
		if descartado < offset {
			return nil, fmt.Errorf("stream: el origen se cortó en %d, se pedía %d", descartado, offset)
		}
	}

	// Lectura acotada: nunca más de lo pedido.
	//
	// Sin longitud explícita se usa el TAMAÑO DE TROZO CONFIGURADO (Ajustes →
	// Rendimiento: 128 KB en bajo, 256 KB en medio, 512 KB en alto). Así ese
	// control hace algo real en este camino, en vez de ser un número que solo
	// viajaba al backend para nada.
	limite := length
	if limite <= 0 {
		if offset > 0 {
			limite = chunkSize.Load()
		} else {
			// Sin rango: "dame el archivo", con techo de seguridad.
			limite = maxChunkSinRango
		}
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, limite))
	if err != nil {
		return nil, err
	}

	// OJO: aquí NO se escribe en s.cache. Se hacía, y era puro gasto de RAM en
	// el dispositivo: nadie lee ese caché (el único que lo tocaba era el propio
	// Add; la ruta de escritorio entrega el audio por streaming, no por trozos
	// cacheados). Cada trozo servido quedaba retenido 5 minutos sin un solo
	// lector, así que escuchar un FLAC de 40 MB dejaba 40 MB de copias vivas.
	// El tipo Cache queda porque las pruebas de concurrencia lo ejercitan.
	return data, nil
}
