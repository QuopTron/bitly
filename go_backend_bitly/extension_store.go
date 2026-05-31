package gobackend

import (
	"archive/zip"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

const (
	CategoryMetadata    = "metadata"
	CategoryDownload    = "download"
	CategoryUtility     = "utility"
	CategoryLyrics      = "lyrics"
	CategoryIntegration = "integration"
)

type storeExtension struct {
	ID               string   `json:"id"`
	Name             string   `json:"name"`
	DisplayName      string   `json:"display_name,omitempty"`
	Version          string   `json:"version"`
	Description      string   `json:"description"`
	DownloadURL      string   `json:"download_url,omitempty"`
	IconURL          string   `json:"icon_url,omitempty"`
	Category         string   `json:"category"`
	Tags             []string `json:"tags,omitempty"`
	Downloads        int      `json:"downloads"`
	UpdatedAt        string   `json:"updated_at"`
	MinAppVersion    string   `json:"min_app_version,omitempty"`
	DisplayNameAlt   string   `json:"displayName,omitempty"`
	DownloadURLAlt   string   `json:"downloadUrl,omitempty"`
	IconURLAlt       string   `json:"iconUrl,omitempty"`
	MinAppVersionAlt string   `json:"minAppVersion,omitempty"`
}

func (e *storeExtension) getDisplayName() string {
	if e.DisplayName != "" {
		return e.DisplayName
	}
	if e.DisplayNameAlt != "" {
		return e.DisplayNameAlt
	}
	return e.Name
}

func (e *storeExtension) getDownloadURL() string {
	if e.DownloadURL != "" {
		return e.DownloadURL
	}
	return e.DownloadURLAlt
}

func (e *storeExtension) getIconURL() string {
	if e.IconURL != "" {
		return e.IconURL
	}
	return e.IconURLAlt
}

func (e *storeExtension) getMinAppVersion() string {
	if e.MinAppVersion != "" {
		return e.MinAppVersion
	}
	return e.MinAppVersionAlt
}

type storeRegistry struct {
	Version    int              `json:"version"`
	UpdatedAt  string           `json:"updated_at"`
	Extensions []storeExtension `json:"extensions"`
}

type storeExtensionResponse struct {
	ID               string   `json:"id"`
	Name             string   `json:"name"`
	DisplayName      string   `json:"display_name"`
	Version          string   `json:"version"`
	Description      string   `json:"description"`
	DownloadURL      string   `json:"download_url"`
	IconURL          string   `json:"icon_url,omitempty"`
	Category         string   `json:"category"`
	Tags             []string `json:"tags,omitempty"`
	Downloads        int      `json:"downloads"`
	UpdatedAt        string   `json:"updated_at"`
	MinAppVersion    string   `json:"min_app_version,omitempty"`
	IsInstalled      bool     `json:"is_installed"`
	InstalledVersion string   `json:"installed_version,omitempty"`
	HasUpdate        bool     `json:"has_update"`
}

func (e *storeExtension) toResponse() storeExtensionResponse {
	resp := storeExtensionResponse{
		ID:            e.ID,
		Name:          e.Name,
		DisplayName:   e.getDisplayName(),
		Version:       e.Version,
		Description:   e.Description,
		DownloadURL:   e.getDownloadURL(),
		IconURL:       e.getIconURL(),
		Category:      e.Category,
		Downloads:     e.Downloads,
		UpdatedAt:     e.UpdatedAt,
		MinAppVersion: e.getMinAppVersion(),
	}

	if len(e.Tags) > 0 {
		resp.Tags = append([]string(nil), e.Tags...)
	}

	return resp
}

type extensionStore struct {
	registryURL string
	cacheDir    string
	cache       *storeRegistry
	cacheMu     sync.RWMutex
	cacheTime   time.Time
	cacheTTL    time.Duration
}

var (
	globalExtensionStore *extensionStore
	extensionStoreMu     sync.Mutex
)

const (
	cacheTTL      = 30 * time.Minute
	cacheFileName = "store_cache.json"
	// Default registry URL - used if not explicitly set via SetStoreRegistryURLJSON
	defaultRegistryURL = "https://raw.githubusercontent.com/Bitlyapp.bitly-extension/main/registry.json"
)

func initExtensionStore(cacheDir string) *extensionStore {
	extensionStoreMu.Lock()
	defer extensionStoreMu.Unlock()

	if globalExtensionStore == nil {
		globalExtensionStore = &extensionStore{
			registryURL: defaultRegistryURL, // Auto-configure with default URL
			cacheDir:    cacheDir,
			cacheTTL:    cacheTTL,
		}
		globalExtensionStore.loadDiskCache()
	}
	return globalExtensionStore
}

func (s *extensionStore) setRegistryURL(registryURL string) {
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()

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

	LogInfo("ExtensionStore", "Registry URL updated to: %s", registryURL)
}

func (s *extensionStore) getRegistryURL() string {
	s.cacheMu.RLock()
	defer s.cacheMu.RUnlock()
	return s.registryURL
}

func getExtensionStore() *extensionStore {
	extensionStoreMu.Lock()
	defer extensionStoreMu.Unlock()
	return globalExtensionStore
}

func (s *extensionStore) loadDiskCache() {
	if s.cacheDir == "" {
		return
	}

	cachePath := filepath.Join(s.cacheDir, cacheFileName)
	data, err := os.ReadFile(cachePath)
	if err != nil {
		return
	}

	var cacheData struct {
		Registry  storeRegistry `json:"registry"`
		CacheTime int64         `json:"cache_time"`
	}

	if err := json.Unmarshal(data, &cacheData); err != nil {
		return
	}

	s.cache = &cacheData.Registry
	s.cacheTime = time.Unix(cacheData.CacheTime, 0)
	LogDebug("ExtensionStore", "Loaded %d extensions from disk cache", len(s.cache.Extensions))
}

func (s *extensionStore) saveDiskCache() {
	if s.cacheDir == "" || s.cache == nil {
		return
	}

	cacheData := struct {
		Registry  storeRegistry `json:"registry"`
		CacheTime int64         `json:"cache_time"`
	}{
		Registry:  *s.cache,
		CacheTime: s.cacheTime.Unix(),
	}

	data, err := json.Marshal(cacheData)
	if err != nil {
		return
	}

	cachePath := filepath.Join(s.cacheDir, cacheFileName)
	os.WriteFile(cachePath, data, 0644)
}

func (s *extensionStore) fetchRegistry(forceRefresh bool) (*storeRegistry, error) {
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()

	if s.registryURL == "" {
		return nil, fmt.Errorf("no registry URL configured. Please add a repository URL first")
	}

	if !forceRefresh && s.cache != nil && time.Since(s.cacheTime) < s.cacheTTL {
		LogDebug("ExtensionStore", "Using cached registry (%d extensions)", len(s.cache.Extensions))
		return s.cache, nil
	}

	if err := requireHTTPSURL(s.registryURL, "registry"); err != nil {
		return nil, err
	}

	LogInfo("ExtensionStore", "Fetching registry from %s", s.registryURL)

	client := NewHTTPClientWithTimeout(30 * time.Second)
	req, err := http.NewRequest(http.MethodGet, s.registryURL, nil)
	if err != nil {
		if s.cache != nil {
			LogWarn("ExtensionStore", "Failed to build registry request, using cached registry: %v", err)
			return s.cache, nil
		}
		return nil, fmt.Errorf("failed to build registry request: %w", err)
	}
	req.Header.Set("Cache-Control", "no-cache")
	req.Header.Set("Pragma", "no-cache")
	resp, err := client.Do(req)
	if err != nil {
		if s.cache != nil {
			LogWarn("ExtensionStore", "Network error, using cached registry: %v", err)
			return s.cache, nil
		}
		return nil, fmt.Errorf("failed to fetch registry: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		if s.cache != nil {
			LogWarn("ExtensionStore", "HTTP %d, using cached registry", resp.StatusCode)
			return s.cache, nil
		}
		return nil, fmt.Errorf("registry returned HTTP %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read registry: %w", err)
	}

	var registry storeRegistry
	if err := json.Unmarshal(body, &registry); err != nil {
		return nil, fmt.Errorf("failed to parse registry: %w", err)
	}

	s.cache = &registry
	s.cacheTime = time.Now()
	s.saveDiskCache()

	LogInfo("ExtensionStore", "Fetched %d extensions from registry", len(registry.Extensions))
	return &registry, nil
}

func (s *extensionStore) getExtensionsWithStatus(forceRefresh bool) ([]storeExtensionResponse, error) {
	registry, err := s.fetchRegistry(forceRefresh)
	if err != nil {
		return nil, err
	}

	manager := getExtensionManager()
	installed := make(map[string]string)    // normalized id -> version
	rawInstalled := make(map[string]string) // original id -> version

	if manager != nil {
		for _, ext := range manager.GetAllExtensions() {
			rawInstalled[ext.ID] = ext.Manifest.Version
			installed[normalizeStoreID(ext.ID)] = ext.Manifest.Version
		}
	}

	LogDebug("ExtensionStore", "Building store response for %d registry extensions (%d installed, %d normalized)", len(registry.Extensions), len(rawInstalled), len(installed))

	result := make([]storeExtensionResponse, 0, len(registry.Extensions))
	for i := range registry.Extensions {
		ext := &registry.Extensions[i]
		resp := ext.toResponse()

		// Try matching by exact ID first, then by normalized ID
		storeID := ext.ID
		normStoreID := normalizeStoreID(storeID)

		if installedVersion, ok := rawInstalled[storeID]; ok {
			resp.IsInstalled = true
			resp.InstalledVersion = installedVersion
			resp.HasUpdate = compareVersions(ext.Version, installedVersion) > 0
		} else if installedVersion, ok := installed[normStoreID]; ok {
			resp.IsInstalled = true
			resp.InstalledVersion = installedVersion
			resp.HasUpdate = compareVersions(ext.Version, installedVersion) > 0
		}

		result = append(result, resp)
	}

	LogDebug("ExtensionStore", "Built store response payload for %d extensions", len(result))
	return result, nil
}

func normalizeStoreID(id string) string {
	s := strings.ToLower(id)
	s = strings.ReplaceAll(s, " ", "-")
	s = strings.ReplaceAll(s, "_", "-")
	return s
}

func (s *extensionStore) downloadExtension(extensionID string, destPath string) error {
	registry, err := s.fetchRegistry(false)
	if err != nil {
		return err
	}

	var ext *storeExtension
	for _, e := range registry.Extensions {
		if e.ID == extensionID {
			ext = &e
			break
		}
	}

	if ext == nil {
		return fmt.Errorf("extension %s not found in store", extensionID)
	}

	if err := requireHTTPSURL(ext.getDownloadURL(), "extension download"); err != nil {
		return err
	}

	LogInfo("ExtensionStore", "Downloading %s from %s", ext.getDisplayName(), ext.getDownloadURL())

	client := NewHTTPClientWithTimeout(5 * time.Minute)
	req, err := http.NewRequest(http.MethodGet, ext.getDownloadURL(), nil)
	if err != nil {
		return fmt.Errorf("failed to build download request: %w", err)
	}
	req.Header.Set("Cache-Control", "no-cache")
	req.Header.Set("Pragma", "no-cache")
	// Some servers may reject empty/unknown User-Agent headers; set a conservative UA
	req.Header.Set("User-Agent", "Bitly-Android/1.0 (+https://Bitly.zarz.moe)")
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to download: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download returned HTTP %d", resp.StatusCode)
	}

	// capture some response headers for debug
	headersJsonBytes, _ := json.Marshal(resp.Header)

	// Ensure destination directory exists
	destDir := filepath.Dir(destPath)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return fmt.Errorf("failed to create destination directory: %w", err)
	}

	tmpPath := destPath + ".part"
	out, err := os.Create(tmpPath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	// don't defer out.Close() — we control closing and removing atomically

	// Peek first bytes to help debug cases where server returns HTML (error page) instead of a ZIP
	peek := make([]byte, 512)
	n, _ := io.ReadFull(resp.Body, peek)
	// Write the peeked bytes to file
	if n > 0 {
		if _, werr := out.Write(peek[:n]); werr != nil {
			out.Close()
			os.Remove(tmpPath)
			return fmt.Errorf("failed to write file: %w", werr)
		}
	}

	// Copy the rest
	_, err = io.Copy(out, resp.Body)
	if err != nil {
		out.Close()
		os.Remove(tmpPath)
		return fmt.Errorf("failed to write file: %w", err)
	}
	out.Close()

	// Atomically rename into place
	if err := os.Rename(tmpPath, destPath); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("failed to rename downloaded file into place: %w", err)
	}

	// Quick check: ZIP files start with 'PK\x03\x04'
	if n >= 4 && !(peek[0] == 'P' && peek[1] == 'K' && peek[2] == 3 && peek[3] == 4) {
		// Not starting with PK — log and still attempt to open to provide useful error
		LogWarn("ExtensionStore", "Downloaded file for %s does not start with ZIP magic bytes (first bytes: %x) — attempting to open anyway", ext.getDisplayName(), peek[:minInt(n, 16)])
	}

	// Validate that the downloaded file is a valid .bitly-ext (zip with manifest.json and index.js)
	zipReader, err2 := zip.OpenReader(destPath)
	if err2 != nil {
		// write debug file with headers + peek
		debugPath := destPath + ".debug.txt"
		debugContent := fmt.Sprintf("url: %s\nstatus: %d\nheaders: %s\npeek_first_bytes_hex: %x\n", ext.getDownloadURL(), resp.StatusCode, string(headersJsonBytes), peek[:minInt(n, 64)])
		_ = os.WriteFile(debugPath, []byte(debugContent), 0644)
		os.Remove(destPath)
		return fmt.Errorf("downloaded file is not a valid zip package: %w", err2)
	}
	foundManifest := false
	foundIndex := false
	var entryNames []string
	for _, f := range zipReader.File {
		name := filepath.Base(f.Name)
		entryNames = append(entryNames, f.Name)
		if name == "manifest.json" {
			foundManifest = true
		}
		if name == "index.js" {
			foundIndex = true
		}
	}
	entryList := strings.Join(entryNames, ", ")
	zipReader.Close()
	if !foundManifest || !foundIndex {
		// write debug file with headers + peek and listing of zip entries
		debugPath := destPath + ".debug.txt"
		debugContent := fmt.Sprintf("url: %s\nstatus: %d\nheaders: %s\nzip_entries: %s\npeek_first_bytes_hex: %x\n", ext.getDownloadURL(), resp.StatusCode, string(headersJsonBytes), entryList, peek[:minInt(n, 64)])
		_ = os.WriteFile(debugPath, []byte(debugContent), 0644)

		os.Remove(destPath)
		return fmt.Errorf("downloaded file is not a valid .bitly-ext package: missing manifest.json or index.js")
	}

	LogInfo("ExtensionStore", "Downloaded %s to %s", ext.getDisplayName(), destPath)
	return nil
}

func resolveRegistryURL(input string) (string, error) {
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
	parts := strings.SplitN(path, "/", 3) // owner, repo, [rest]
	if len(parts) < 2 || parts[0] == "" || parts[1] == "" {
		return "", fmt.Errorf("invalid GitHub URL: expected github.com/<owner>/<repo>")
	}
	owner := parts[0]
	repo := strings.TrimSuffix(parts[1], ".git")

	branch := resolveGitHubDefaultBranch(owner, repo)

	resolved := fmt.Sprintf("https://raw.githubusercontent.com/%s/%s/%s/registry.json", owner, repo, branch)
	LogInfo("ExtensionStore", "Resolved %s → %s (branch: %s)", input, resolved, branch)
	return resolved, nil
}

func resolveGitHubDefaultBranch(owner, repo string) string {
	apiURL := fmt.Sprintf("https://api.github.com/repos/%s/%s", owner, repo)
	client := NewHTTPClientWithTimeout(10 * time.Second)

	resp, err := client.Get(apiURL)
	if err != nil {
		LogWarn("ExtensionStore", "GitHub API request failed for %s/%s: %v – falling back to main", owner, repo, err)
		return "main"
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		LogWarn("ExtensionStore", "GitHub API returned %d for %s/%s – falling back to main", resp.StatusCode, owner, repo)
		return "main"
	}

	var info struct {
		DefaultBranch string `json:"default_branch"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil || info.DefaultBranch == "" {
		LogWarn("ExtensionStore", "Could not parse default_branch for %s/%s – falling back to main", owner, repo)
		return "main"
	}

	return info.DefaultBranch
}

func requireHTTPSURL(rawURL string, context string) error {
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

func (s *extensionStore) getCategories() []string {
	return []string{
		CategoryMetadata,
		CategoryDownload,
		CategoryUtility,
		CategoryLyrics,
		CategoryIntegration,
	}
}

func (s *extensionStore) searchExtensions(query string, category string) ([]storeExtensionResponse, error) {
	extensions, err := s.getExtensionsWithStatus(false)
	if err != nil {
		return nil, err
	}

	if query == "" && category == "" {
		return extensions, nil
	}

	result := make([]storeExtensionResponse, 0, len(extensions))
	queryLower := toLower(query)

	for _, ext := range extensions {
		if category != "" && ext.Category != category {
			continue
		}

		if query != "" {
			if !containsIgnoreCase(ext.Name, queryLower) &&
				!containsIgnoreCase(ext.DisplayName, queryLower) &&
				!containsIgnoreCase(ext.Description, queryLower) {
				found := false
				for _, tag := range ext.Tags {
					if containsIgnoreCase(tag, queryLower) {
						found = true
						break
					}
				}
				if !found {
					continue
				}
			}
		}

		result = append(result, ext)
	}

	return result, nil
}

func (s *extensionStore) clearCache() {
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()

	s.cache = nil
	s.cacheTime = time.Time{}

	if s.cacheDir != "" {
		cachePath := filepath.Join(s.cacheDir, cacheFileName)
		os.Remove(cachePath)
	}

	LogInfo("ExtensionStore", "Cache cleared")
}

func containsIgnoreCase(s, substr string) bool {
	return containsStr(toLower(s), substr)
}

func toLower(s string) string {
	result := make([]byte, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'A' && c <= 'Z' {
			c += 'a' - 'A'
		}
		result[i] = c
	}
	return string(result)
}

func containsStr(s, substr string) bool {
	return len(substr) == 0 || (len(s) >= len(substr) && findSubstring(s, substr) >= 0)
}

func findSubstring(s, substr string) int {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}
