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
func (s *Streamer) fetchChunk(audioURL string, from int64) (*http.Response, error) {
	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			time.Sleep(time.Duration(attempt) * 300 * time.Millisecond)
		}
		req, err := http.NewRequest("GET", audioURL, nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", from, from+streamChunkSize-1))
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
