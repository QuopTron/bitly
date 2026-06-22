package store

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

func httpGet(rawURL string, timeout time.Duration) ([]byte, int, error) {
	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(rawURL)
	if err != nil {
		return nil, 0, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, resp.StatusCode, fmt.Errorf("failed to read response: %w", err)
	}
	return body, resp.StatusCode, nil
}

func (s *Store) FetchRegistry(forceRefresh bool) (*storeRegistry, error) {
	s.mu.Lock()
	if s.registryURL == "" {
		s.mu.Unlock()
		return nil, fmt.Errorf("no registry URL configured. Please add a repository URL first")
	}
	if !forceRefresh && s.cache != nil && time.Since(s.cacheTime) < s.cacheTTL {
		reg := s.cache
		s.mu.Unlock()
		return reg, nil
	}
	registryURL := s.registryURL
	s.mu.Unlock()

	if err := requireHTTPSURL(registryURL, "registry"); err != nil {
		return nil, err
	}

	body, statusCode, err := httpGet(registryURL, registryTimeout)
	if err != nil {
		s.mu.RLock()
		cached := s.cache
		s.mu.RUnlock()
		if cached != nil {
			return cached, nil
		}
		return nil, fmt.Errorf("failed to fetch registry: %w", err)
	}

	if statusCode != http.StatusOK {
		s.mu.RLock()
		cached := s.cache
		s.mu.RUnlock()
		if cached != nil {
			return cached, nil
		}
		return nil, fmt.Errorf("registry returned HTTP %d", statusCode)
	}

	var registry storeRegistry
	if err := json.Unmarshal(body, &registry); err != nil {
		return nil, fmt.Errorf("failed to parse registry: %w", err)
	}

	s.mu.Lock()
	s.cache = &registry
	s.cacheTime = time.Now()
	s.mu.Unlock()
	s.saveDiskCache()
	return &registry, nil
}
