package extensions

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// ═══════════════════════════════════════════════════════════════════════
// Extension Repository / Store — remote catalog for extension discovery
// ═══════════════════════════════════════════════════════════════════════

const (
	maxPackageSize    = 64 * 1024 * 1024 // 64 MiB limit
	repoCacheTTL      = 30 * time.Minute
	sha256HexSize     = 64
)

// RepoExtension represents an extension in the remote registry.
type RepoExtension struct {
	ID            string   `json:"id"`
	Name          string   `json:"name"`
	DisplayName   string   `json:"display_name"`
	Description   string   `json:"description"`
	Version       string   `json:"version"`
	Author        string   `json:"author"`
	Category      string   `json:"category"` // metadata, download, utility, lyrics, integration
	DownloadURL   string   `json:"download_url"`
	SHA256        string   `json:"sha256"`
	SizeBytes     int64    `json:"size_bytes"`
	ScreenshotURL string   `json:"screenshot_url,omitempty"`
	Tags          []string `json:"tags,omitempty"`
}

// RepoCategory represents a category of extensions.
type RepoCategory struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Count       int    `json:"count"`
}

// RepoRegistry holds the remote extension registry data.
type RepoRegistry struct {
	Extensions []RepoExtension `json:"extensions"`
	Categories []RepoCategory  `json:"categories"`
	Version    string          `json:"version"`
	UpdatedAt  time.Time       `json:"updated_at"`
}

// ExtensionStore manages the extension repository.
type ExtensionStore struct {
	mu           sync.RWMutex
	registryURL  string
	cache        *RepoRegistry
	cacheExpiry  time.Time
	httpClient   *http.Client
	extensionsDir string
	dataDir      string
	installed    map[string]string // id → version
}

// NewExtensionStore creates a new extension store.
func NewExtensionStore(extensionsDir, dataDir string) *ExtensionStore {
	return &ExtensionStore{
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				if len(via) >= 3 {
					return fmt.Errorf("too many redirects")
				}
				return nil
			},
		},
		extensionsDir: extensionsDir,
		dataDir:       dataDir,
		installed:     make(map[string]string),
	}
}

// SetRegistryURL configures the remote registry URL.
func (es *ExtensionStore) SetRegistryURL(url string) error {
	url = strings.TrimSpace(url)
	if url == "" {
		return fmt.Errorf("empty registry URL")
	}
	if !strings.HasPrefix(url, "https://") && !strings.HasPrefix(url, "http://") {
		return fmt.Errorf("registry URL must start with https:// or http://")
	}
	es.mu.Lock()
	es.registryURL = url
	es.cache = nil // invalidate cache on URL change
	es.mu.Unlock()
	log.Printf("[ext-store] registry URL set to %s", url)
	return nil
}

// ClearRegistryURL removes the configured registry URL.
func (es *ExtensionStore) ClearRegistryURL() {
	es.mu.Lock()
	es.registryURL = ""
	es.cache = nil
	es.mu.Unlock()
}

// GetRegistry fetches the extension registry from the remote URL.
func (es *ExtensionStore) GetRegistry() (*RepoRegistry, error) {
	es.mu.RLock()
	if es.registryURL == "" {
		es.mu.RUnlock()
		return nil, fmt.Errorf("no registry URL configured")
	}
	if es.cache != nil && time.Now().Before(es.cacheExpiry) {
		cached := es.cache
		es.mu.RUnlock()
		return cached, nil
	}
	es.mu.RUnlock()

	es.mu.Lock()
	defer es.mu.Unlock()

	// Double-check after acquiring write lock
	if es.cache != nil && time.Now().Before(es.cacheExpiry) {
		return es.cache, nil
	}

	url := es.registryURL
	if !strings.HasSuffix(url, "/") {
		url += "/"
	}
	url += "extensions.json"

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "Bitly/1.0")

	resp, err := es.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch registry: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("registry returned HTTP %d", resp.StatusCode)
	}

	// Limit response size
	limitedReader := io.LimitReader(resp.Body, 10*1024*1024) // 10MB
	var registry RepoRegistry
	if err := json.NewDecoder(limitedReader).Decode(&registry); err != nil {
		return nil, fmt.Errorf("failed to parse registry: %w", err)
	}

	registry.UpdatedAt = time.Now()
	es.cache = &registry
	es.cacheExpiry = time.Now().Add(repoCacheTTL)

	log.Printf("[ext-store] registry fetched: %d extensions, %d categories",
		len(registry.Extensions), len(registry.Categories))
	return &registry, nil
}

// SearchExtensions searches the registry by query and category.
func (es *ExtensionStore) SearchExtensions(query, category string) ([]RepoExtension, error) {
	registry, err := es.GetRegistry()
	if err != nil {
		return nil, err
	}

	query = strings.ToLower(strings.TrimSpace(query))
	category = strings.ToLower(strings.TrimSpace(category))

	var results []RepoExtension
	for _, ext := range registry.Extensions {
		if category != "" && strings.ToLower(ext.Category) != category {
			continue
		}
		if query != "" {
			match := strings.Contains(strings.ToLower(ext.Name), query) ||
				strings.Contains(strings.ToLower(ext.DisplayName), query) ||
				strings.Contains(strings.ToLower(ext.Description), query) ||
				strings.Contains(strings.ToLower(ext.ID), query)
			for _, tag := range ext.Tags {
				if strings.Contains(strings.ToLower(tag), query) {
					match = true
					break
				}
			}
			if !match {
				continue
			}
		}
		results = append(results, ext)
	}
	return results, nil
}

// GetCategories returns available extension categories.
func (es *ExtensionStore) GetCategories() ([]RepoCategory, error) {
	registry, err := es.GetRegistry()
	if err != nil {
		return nil, err
	}
	return registry.Categories, nil
}

// DownloadExtension downloads an extension package with SHA-256 verification.
func (es *ExtensionStore) DownloadExtension(ext RepoExtension) (string, error) {
	if ext.DownloadURL == "" {
		return "", fmt.Errorf("no download URL for extension %s", ext.ID)
	}

	// Verify installed version
	es.mu.RLock()
	if installedVer, ok := es.installed[ext.ID]; ok && installedVer == ext.Version {
		es.mu.RUnlock()
		return "", fmt.Errorf("extension %s v%s is already installed", ext.ID, ext.Version)
	}
	es.mu.RUnlock()

	// Download with size limit
	req, err := http.NewRequest("GET", ext.DownloadURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "Bitly/1.0")

	resp, err := es.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("download failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("download returned HTTP %d", resp.StatusCode)
	}

	// Check Content-Length if available
	if resp.ContentLength > maxPackageSize {
		return "", fmt.Errorf("package too large: %d bytes (max %d)", resp.ContentLength, maxPackageSize)
	}

	// Read with size limit
	limitedReader := io.LimitReader(resp.Body, maxPackageSize+1)
	data, err := io.ReadAll(limitedReader)
	if err != nil {
		return "", fmt.Errorf("download failed: %w", err)
	}
	if int64(len(data)) > maxPackageSize {
		return "", fmt.Errorf("package exceeds size limit")
	}

	// SHA-256 verification
	if ext.SHA256 != "" {
		hash := sha256.Sum256(data)
		actual := hex.EncodeToString(hash[:])
		if !strings.EqualFold(actual, ext.SHA256) {
			return "", fmt.Errorf("SHA-256 mismatch: expected %s, got %s", ext.SHA256, actual)
		}
	}

	// Determine file extension
	urlPath := ext.DownloadURL
	extName := ext.ID
	if idx := strings.LastIndex(urlPath, "/"); idx >= 0 {
		urlPath = urlPath[idx+1:]
	}
	if strings.HasSuffix(urlPath, ".spotiflac-ext") || strings.HasSuffix(urlPath, ".sflx") {
		// Use original extension
	}

	// Save to file
	if err := os.MkdirAll(es.extensionsDir, 0755); err != nil {
		return "", err
	}
	filePath := filepath.Join(es.extensionsDir, extName+".spotiflac-ext")
	if err := os.WriteFile(filePath, data, 0644); err != nil {
		return "", err
	}

	// Record installed version
	es.mu.Lock()
	es.installed[ext.ID] = ext.Version
	es.mu.Unlock()

	log.Printf("[ext-store] downloaded %s v%s (%d bytes, SHA-256 verified: %v)",
		ext.ID, ext.Version, len(data), ext.SHA256 != "")
	return filePath, nil
}

// ClearCache invalidates the local registry cache.
func (es *ExtensionStore) ClearCache() {
	es.mu.Lock()
	defer es.mu.Unlock()
	es.cache = nil
	es.cacheExpiry = time.Time{}
}

// GetInstalledVersions returns the map of installed extension versions.
func (es *ExtensionStore) GetInstalledVersions() map[string]string {
	es.mu.RLock()
	defer es.mu.RUnlock()
	result := make(map[string]string, len(es.installed))
	for k, v := range es.installed {
		result[k] = v
	}
	return result
}

// MarkInstalled records that an extension version is installed.
func (es *ExtensionStore) MarkInstalled(id, version string) {
	es.mu.Lock()
	defer es.mu.Unlock()
	es.installed[id] = version
}
