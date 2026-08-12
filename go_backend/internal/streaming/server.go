package streaming

import (
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// Streamer handles audio streaming over HTTP with range support.
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

// StreamURL proxies an audio URL with Range support for desktop.
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

// StreamChunk fetches a byte range of audio for mobile/AAR use.
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

	if offset >= 0 {
		idx := int(offset / int64(chunkSize))
		s.cache.Add(audioURL, Chunk{Data: data, Index: idx, Size: len(data), IsLast: len(data) < int(length)})
	}

	return data, nil
}
