package streaming

import (
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// Streamer handles audio streaming over HTTP with range support.
// Desktop: uses an HTTP server (Start/Stop).
// Mobile: uses StreamChunk for direct byte access.
type Streamer struct {
	client  *http.Client
	cache   *Cache
	server  *http.Server
}

// NewStreamer creates an audio streamer.
func NewStreamer() *Streamer {
	return &Streamer{
		client: &http.Client{Timeout: 30 * time.Second},
		cache:  NewCache(),
	}
}

// StreamURL creates a stream from a direct audio URL (desktop HTTP handler).
// Supports HTTP Range requests for seeking.
func (s *Streamer) StreamURL(w http.ResponseWriter, r *http.Request, audioURL string) error {
	req, err := http.NewRequest("GET", audioURL, nil)
	if err != nil {
		return err
	}

	if rangeHeader := r.Header.Get("Range"); rangeHeader != "" {
		req.Header.Set("Range", rangeHeader)
	}
	req.Header.Set("User-Agent", httpclient.RandomUserAgent())

	resp, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	w.Header().Set("Accept-Ranges", "bytes")
	if resp.Header.Get("Content-Range") != "" {
		w.Header().Set("Content-Range", resp.Header.Get("Content-Range"))
	}
	if resp.Header.Get("Content-Length") != "" {
		w.Header().Set("Content-Length", resp.Header.Get("Content-Length"))
	}
	if resp.Header.Get("Content-Type") != "" {
		w.Header().Set("Content-Type", resp.Header.Get("Content-Type"))
	}

	if resp.StatusCode == http.StatusPartialContent {
		w.WriteHeader(http.StatusPartialContent)
	} else {
		w.WriteHeader(http.StatusOK)
	}

	_, err = io.Copy(w, resp.Body)
	return err
}

// StreamChunk fetches a byte range of audio directly (mobile/AAR use).
// Returns the bytes directly for Flutter to play via native APIs.
func (s *Streamer) StreamChunk(audioURL string, offset, length int64) ([]byte, error) {
	req, err := http.NewRequest("GET", audioURL, nil)
	if err != nil {
		return nil, err
	}

	if offset >= 0 && length > 0 {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", offset, offset+length-1))
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

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	// Cache the chunk
	if offset >= 0 {
		idx := int(offset / chunkSize)
		s.cache.Add(audioURL, Chunk{Data: data, Index: idx, Size: len(data), IsLast: len(data) < int(length)})
	}

	return data, nil
}

// StartServer starts an HTTP server on the given port that proxies audio streams.
// Only for desktop use. Returns the server address.
func (s *Streamer) StartServer(port int) (string, error) {
	mux := http.NewServeMux()
	mux.HandleFunc("/stream", func(w http.ResponseWriter, r *http.Request) {
		audioURL := r.URL.Query().Get("url")
		if audioURL == "" {
			http.Error(w, "missing url", http.StatusBadRequest)
			return
		}
		if err := s.StreamURL(w, r, audioURL); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
	})
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok"}`))
	})

	addr := fmt.Sprintf(":%d", port)
	s.server = &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	go func() {
		s.server.ListenAndServe()
	}()

	return fmt.Sprintf("http://localhost%s", addr), nil
}

// StopServer stops the streaming HTTP server.
func (s *Streamer) StopServer() error {
	if s.server != nil {
		return s.server.Close()
	}
	return nil
}

// ParseRange parses a Range header into offset and length.
func ParseRange(rangeHeader string, fileSize int64) (offset, length int64, err error) {
	if rangeHeader == "" {
		return 0, fileSize, nil
	}
	if !strings.HasPrefix(rangeHeader, "bytes=") {
		return 0, 0, fmt.Errorf("invalid range")
	}
	rangeStr := strings.TrimPrefix(rangeHeader, "bytes=")
	parts := strings.Split(rangeStr, "-")
	if len(parts) != 2 {
		return 0, 0, fmt.Errorf("invalid range format")
	}

	start, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return 0, 0, err
	}

	var end int64
	if parts[1] != "" {
		end, err = strconv.ParseInt(parts[1], 10, 64)
		if err != nil {
			return 0, 0, err
		}
	} else {
		end = fileSize - 1
	}

	return start, end - start + 1, nil
}
