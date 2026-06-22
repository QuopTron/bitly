package tidal

import (
	"net/http"
	"sync"
	"time"
)

const (
	providerName = "tidal_monochrome"
	metadataTTL  = 10 * time.Minute
)

type Client struct {
	httpClient *http.Client
	cache      map[string]*cacheEntry
	mu         sync.RWMutex
	baseURLs   []string
}

var (
	globalClient     *Client
	globalClientOnce sync.Once
)

func GetClient() *Client {
	globalClientOnce.Do(func() {
		c := &Client{
			httpClient: &http.Client{Timeout: 15 * time.Second},
			cache:      make(map[string]*cacheEntry),
		}
		c.refreshServers()
		go c.periodicRefresh()
		globalClient = c
	})
	return globalClient
}
