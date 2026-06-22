package store

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func (s *Store) SetRegistryURL(registryURL string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.registryURL == registryURL {
		return
	}
	s.registryURL = registryURL
	s.cache = nil
	s.cacheTime = time.Time{}
	if s.cacheDir != "" {
		cachePath := filepath.Join(s.cacheDir, cacheFileName)
		os.Remove(cachePath)
	}
}

func (s *Store) GetRegistryURL() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.registryURL
}

func (s *Store) ResolveRegistryURL(input string) (string, error) {
	input = strings.TrimSpace(input)
	if input == "" {
		return "", fmt.Errorf("registry URL is empty")
	}
	if strings.Contains(input, "raw.githubusercontent.com") {
		return input, nil
	}

	const ghPrefix = "https://github.com/"
	if !strings.HasPrefix(input, ghPrefix) {
		const ghPrefixHTTP = "http://github.com/"
		if strings.HasPrefix(input, ghPrefixHTTP) {
			input = "https://github.com/" + input[len(ghPrefixHTTP):]
		} else {
			return input, nil
		}
	}

	path := input[len(ghPrefix):]
	parts := strings.SplitN(path, "/", 3)
	if len(parts) < 2 || parts[0] == "" || parts[1] == "" {
		return "", fmt.Errorf("invalid GitHub URL: expected github.com/<owner>/<repo>")
	}
	owner := parts[0]
	repo := strings.TrimSuffix(parts[1], ".git")
	branch := s.resolveGitHubDefaultBranch(owner, repo)
	resolved := fmt.Sprintf("https://raw.githubusercontent.com/%s/%s/%s/registry.json", owner, repo, branch)
	return resolved, nil
}

func (s *Store) resolveGitHubDefaultBranch(owner, repo string) string {
	apiURL := fmt.Sprintf("https://api.github.com/repos/%s/%s", owner, repo)
	body, statusCode, err := httpGet(apiURL, githubAPITimeout)
	if err != nil || statusCode != http.StatusOK {
		return "main"
	}
	var info struct {
		DefaultBranch string `json:"default_branch"`
	}
	if err := json.Unmarshal(body, &info); err != nil || info.DefaultBranch == "" {
		return "main"
	}
	return info.DefaultBranch
}

func requireHTTPSURL(rawURL, context string) error {
	if rawURL == "" {
		return fmt.Errorf("%s URL is empty", context)
	}
	parsed, err := url.Parse(rawURL)
	if err != nil || parsed.Host == "" {
		return fmt.Errorf("%s URL is invalid: %s", context, rawURL)
	}
	if parsed.Scheme != "https" {
		return fmt.Errorf("%s URL must use https: %s", context, rawURL)
	}
	return nil
}
