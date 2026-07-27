package httpclient

import (
	"math"
	"math/rand"
	"net/http"
	"time"
)

// RetryConfig defines exponential backoff parameters.
type RetryConfig struct {
	MaxRetries int
	BaseDelay  time.Duration
	MaxDelay   time.Duration
	RetryOnEOF bool // retry on connection errors
}

// DefaultRetryConfig returns sensible retry defaults.
func DefaultRetryConfig() RetryConfig {
	return RetryConfig{
		MaxRetries: 3,
		BaseDelay:  1 * time.Second,
		MaxDelay:   30 * time.Second,
		RetryOnEOF: true,
	}
}

// isRetryable returns true if the response status warrants a retry.
func isRetryable(statusCode int) bool {
	switch statusCode {
	case http.StatusTooManyRequests,       // 429
		http.StatusServiceUnavailable,     // 503
		http.StatusBadGateway,             // 502
		http.StatusGatewayTimeout:          // 504
		return true
	}
	return false
}

// DoWithRetry executes an HTTP request with exponential backoff + jitter.
func DoWithRetry(client *http.Client, req *http.Request, cfg RetryConfig) (*http.Response, error) {
	var resp *http.Response
	var err error

	for attempt := 0; attempt <= cfg.MaxRetries; attempt++ {
		if attempt > 0 && req.Body != nil {
			req.Body, err = req.GetBody()
			if err != nil {
				return nil, err
			}
		}

		resp, err = client.Do(req)
		if err != nil {
			if !cfg.RetryOnEOF || attempt == cfg.MaxRetries {
				return nil, err
			}
			delay := backoff(attempt, cfg.BaseDelay, cfg.MaxDelay)
			select {
			case <-time.After(delay):
			case <-req.Context().Done():
				return nil, req.Context().Err()
			}
			continue
		}

		if resp.StatusCode < 500 && resp.StatusCode != 429 {
			return resp, nil
		}
		if attempt == cfg.MaxRetries {
			return resp, nil
		}

		delay := backoff(attempt, cfg.BaseDelay, cfg.MaxDelay)
		resp.Body.Close()
		select {
		case <-time.After(delay):
		case <-req.Context().Done():
			return nil, req.Context().Err()
		}
	}
	return resp, err
}

// backoff calculates delay with full jitter.
func backoff(attempt int, base, max time.Duration) time.Duration {
	delay := float64(base) * math.Pow(2, float64(attempt))
	jitter := rand.Float64() * delay
	delay += jitter
	if delay > float64(max) {
		delay = float64(max)
	}
	return time.Duration(delay)
}
