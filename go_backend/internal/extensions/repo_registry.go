package extensions

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
)

func (es *ExtensionStore) GetRegistry() (*RepoRegistry, error) {
	es.mu.RLock()
	if es.registryURL == "" {
		es.mu.RUnlock()
		return nil, fmt.Errorf("ERR_SIN_REGISTRO: no hay URL de registro configurada")
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
		return nil, fmt.Errorf("ERR_REGISTRO: fallo al obtener el registro: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("registry returned HTTP %d", resp.StatusCode)
	}

	// Limit response size
	limitedReader := io.LimitReader(resp.Body, 10*1024*1024) // 10MB
	var registry RepoRegistry
	if err := json.NewDecoder(limitedReader).Decode(&registry); err != nil {
		return nil, fmt.Errorf("ERR_REGISTRO: fallo al parsear el registro: %w", err)
	}

	registry.UpdatedAt = time.Now()
	es.cache = &registry
	es.cacheExpiry = time.Now().Add(repoCacheTTL)

	log.Printf("[ext-store] registry fetched: %d extensions, %d categories",
		len(registry.Extensions), len(registry.Categories))
	return &registry, nil
}

// SearchExtensions searches the registry by query and category.
