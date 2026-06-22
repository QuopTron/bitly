package availability

import (
	"net/http"
	"sync"
	"time"

	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type ISRCResolutionResult struct {
	ISRC       string `json:"isrc"`
	TidalURL   string `json:"tidal_url,omitempty"`
	QobuzURL   string `json:"qobuz_url,omitempty"`
	DeezerURL  string `json:"deezer_url,omitempty"`
	SpotifyURL string `json:"spotify_url,omitempty"`
	Provider   string `json:"provider"`
}

type LinkResolver struct {
	httpClient       *http.Client
	mu               sync.RWMutex
	resolverPriority []string
}

var (
	globalLinkResolver     *LinkResolver
	globalLinkResolverOnce sync.Once
)

func GetLinkResolver() *LinkResolver {
	globalLinkResolverOnce.Do(func() {
		globalLinkResolver = &LinkResolver{
			httpClient: httpclient.NewMetadataClient(30 * time.Second),
			resolverPriority: []string{"songstats", "deezer_songlink"},
		}
	})
	return globalLinkResolver
}
