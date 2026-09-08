package extensions

import (
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"
)

func NewExtensionStore(extensionsDir, dataDir string) *ExtensionStore {
	return &ExtensionStore{
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				if len(via) >= 3 {
					return fmt.Errorf("ERR_REDIRECCIONES: demasiadas redirecciones")
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
		return fmt.Errorf("ERR_URL_VACIA: URL de registro vacia")
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
