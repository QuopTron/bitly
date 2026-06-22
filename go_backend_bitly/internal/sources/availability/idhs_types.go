package availability

import (
	"net/http"
	"sync"
	"time"

	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type IDHSClient struct {
	client *http.Client
}

var (
	globalIDHSClient *IDHSClient
	idhsClientOnce   sync.Once
	idhsRateLimiter  = httpclient.NewRateLimiter(8, time.Minute)
)

type IDHSSearchRequest struct {
	Link     string   `json:"link"`
	Adapters []string `json:"adapters,omitempty"`
}

type IDHSSearchResponse struct {
	ID            string     `json:"id"`
	Type          string     `json:"type"`
	Title         string     `json:"title"`
	Description   string     `json:"description"`
	Image         string     `json:"image,omitempty"`
	Audio         string     `json:"audio,omitempty"`
	Source        string     `json:"source"`
	UniversalLink string     `json:"universalLink"`
	Links         []IDHSLink `json:"links"`
}

type IDHSLink struct {
	Type         string `json:"type"`
	URL          string `json:"url"`
	IsVerified   bool   `json:"isVerified,omitempty"`
	NotAvailable bool   `json:"notAvailable,omitempty"`
}

func NewIDHSClient() *IDHSClient {
	idhsClientOnce.Do(func() {
		globalIDHSClient = &IDHSClient{
			client: httpclient.NewMetadataClient(15 * time.Second),
		}
	})
	return globalIDHSClient
}
