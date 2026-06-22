package audio

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

func (s *Strategy) Download(ctx context.Context, req AudioRequest) (*AudioResult, error) {
	if req.URL == "" {
		return nil, fmt.Errorf("audio: no URL provided")
	}
	if req.FilePath == "" {
		return nil, fmt.Errorf("audio: no file path provided")
	}

	dir := filepath.Dir(req.FilePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("audio: mkdir %s: %w", dir, err)
	}

	var lastErr error
	attempts := s.retries + 1
	if attempts <= 0 {
		attempts = 1
	}

	for attempt := 1; attempt <= attempts; attempt++ {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		default:
		}

		result, err := s.tryDownload(ctx, req, attempt)
		if err == nil {
			return result, nil
		}
		lastErr = err

		if attempt < attempts {
			backoff := time.Duration(attempt) * 2 * time.Second
			timer := time.NewTimer(backoff)
			select {
			case <-ctx.Done():
				timer.Stop()
				return nil, ctx.Err()
			case <-timer.C:
			}
		}
	}

	return nil, fmt.Errorf("audio: download failed after %d attempts: %w", attempts, lastErr)
}

func (s *Strategy) tryDownload(ctx context.Context, req AudioRequest, attempt int) (*AudioResult, error) {
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, req.URL, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	httpReq.Header.Set("User-Agent", s.userAgent)

	if attempt > 1 {
		if fi, statErr := os.Stat(req.FilePath); statErr == nil && fi.Size() > 0 {
			httpReq.Header.Set("Range", fmt.Sprintf("bytes=%d-", fi.Size()))
		}
	}

	resp, err := s.client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("http request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusRequestedRangeNotSatisfiable {
		fi, statErr := os.Stat(req.FilePath)
		if statErr == nil && fi.Size() > 0 {
			return &AudioResult{
				FilePath:     req.FilePath,
				Size:         fi.Size(),
				Format:       detectFormat(req),
				BytesWritten: 0,
			}, nil
		}
		return nil, fmt.Errorf("range not satisfiable and file invalid")
	}

	if resp.StatusCode == http.StatusPartialContent {
		return s.appendFromResponse(ctx, req, resp)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	return s.writeFromResponse(ctx, req, resp)
}
