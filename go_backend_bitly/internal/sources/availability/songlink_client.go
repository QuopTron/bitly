package availability

import (
	"net/http"
	"strings"
	"sync"
	"time"

	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type Client struct {
	client       *http.Client
	isrcSearcher ISRCSearcher
}

var (
	globalClient     *Client
	globalClientOnce sync.Once
	songLinkRegion   = "US"
	songLinkRegionMu sync.RWMutex
)

const (
	resolveAPIURL = "https://api.zarz.moe/v1/resolve"
	songLinkURL   = "https://api.song.link/v1-alpha.1/links"
	timeout       = 30 * time.Second
)

func NewClient() *Client {
	globalClientOnce.Do(func() {
		globalClient = &Client{
			client: httpclient.NewMetadataClient(timeout),
		}
	})
	return globalClient
}

func (s *Client) SetISRCSearcher(searcher ISRCSearcher) {
	s.isrcSearcher = searcher
}

func SetRegion(region string) {
	normalized := strings.ToUpper(strings.TrimSpace(region))
	if len(normalized) != 2 {
		normalized = "US"
	}
	for _, ch := range normalized {
		if ch < 'A' || ch > 'Z' {
			normalized = "US"
			break
		}
	}
	songLinkRegionMu.Lock()
	songLinkRegion = normalized
	songLinkRegionMu.Unlock()
}

func GetRegion() string {
	songLinkRegionMu.RLock()
	defer songLinkRegionMu.RUnlock()
	return songLinkRegion
}
