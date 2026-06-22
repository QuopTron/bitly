package httpclient

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type RetryConfig struct {
	MaxRetries   int
	InitialDelay time.Duration
	MaxDelay     time.Duration
	Factor       float64
}

func DefaultRetryConfig() RetryConfig {
	return RetryConfig{
		MaxRetries:   3,
		InitialDelay: 500 * time.Millisecond,
		MaxDelay:     5 * time.Second,
		Factor:       2.0,
	}
}

func DoWithRetry(client *http.Client, req *http.Request, config RetryConfig) (*http.Response, error) {
	var resp *http.Response
	var err error

	delay := config.InitialDelay
	for attempt := 0; attempt <= config.MaxRetries; attempt++ {
		reqCopy := req.Clone(req.Context())
		resp, err = client.Do(reqCopy)
		if err == nil && resp.StatusCode < 500 {
			return resp, nil
		}
		if resp != nil && resp.Body != nil {
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
		}
		if attempt == config.MaxRetries {
			break
		}
		time.Sleep(delay)
		delay = time.Duration(float64(delay) * config.Factor)
		if delay > config.MaxDelay {
			delay = config.MaxDelay
		}
	}
	if err != nil {
		return nil, fmt.Errorf("request failed after %d retries: %w", config.MaxRetries, err)
	}
	return resp, nil
}

func ContainsCloudflareChallenge(body string) bool {
	lower := strings.ToLower(body)
	return strings.Contains(lower, "cf-browser-verification") ||
		strings.Contains(lower, "cloudflare") && strings.Contains(lower, "challenge") ||
		strings.Contains(lower, "__cf_chl_tk") ||
		strings.Contains(lower, "just a moment") || strings.Contains(lower, "checking your browser")
}
