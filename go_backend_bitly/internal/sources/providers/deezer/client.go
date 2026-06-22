package deezer

import (
	"net/http"
	"sync"
	"time"

	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

const (
	baseURL          = "https://api.deezer.com/2.0"
	searchURL        = baseURL + "/search"
	trackURL         = baseURL + "/track/%s"
	albumURL         = baseURL + "/album/%s"
	artistURL        = baseURL + "/artist/%s"
	artistRelatedURL = baseURL + "/artist/%s/related"
	playlistURL      = baseURL + "/playlist/%s"

	cacheTTL              = 10 * time.Minute
	maxParallelISRC       = 10
	apiTimeoutMobile      = 25 * time.Second
	maxRetries            = 2
	retryDelay            = 500 * time.Millisecond
	maxSearchCacheEntries = 300
	maxAlbumCacheEntries  = 200
	maxArtistCacheEntries = 200
	maxISRCCacheEntries   = 4000
	cacheCleanupInterval  = 5 * time.Minute
)

type Client struct {
	httpClient           *http.Client
	searchCache          map[string]*cacheEntry
	albumCache           map[string]*cacheEntry
	artistCache          map[string]*cacheEntry
	isrcCache            map[string]string
	cacheMu              sync.RWMutex
	lastCacheCleanup     time.Time
	cacheCleanupInterval time.Duration
}

var (
	globalClient     *Client
	globalClientOnce sync.Once
)

func GetClient() *Client {
	globalClientOnce.Do(func() {
		globalClient = &Client{
			httpClient:           httpclient.NewMetadataClient(apiTimeoutMobile),
			searchCache:          make(map[string]*cacheEntry),
			albumCache:           make(map[string]*cacheEntry),
			artistCache:          make(map[string]*cacheEntry),
			isrcCache:            make(map[string]string),
			cacheCleanupInterval: cacheCleanupInterval,
		}
	})
	return globalClient
}
