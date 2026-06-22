package youtube

import (
	"net/http"
	"sync"
	"time"
)

const (
	ytDlpSearchTimeout    = 30 * time.Second
	ytDlpDownloadTimeout  = 5 * time.Minute
	globalSearchTimeout   = 15 * time.Second
	searchFailureCacheTTL = 5 * time.Minute
)

type Client struct {
	httpClient  *http.Client
	ytdlpPathFn func() string
	innertubeUA string
}

var (
	globalClient     *Client
	globalClientOnce sync.Once
)

func GetClient() *Client {
	globalClientOnce.Do(func() {
		globalClient = &Client{
			httpClient: &http.Client{
				Timeout: 10 * time.Second,
				Transport: &http.Transport{
					DisableKeepAlives: true,
				},
			},
			innertubeUA: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
		}
	})
	return globalClient
}

func (c *Client) SetAndroidMode() {
	c.innertubeUA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36"
}

func (c *Client) SetYtDlpPathFn(fn func() string) {
	c.ytdlpPathFn = fn
}

func (c *Client) getYtDlpPath() string {
	if c.ytdlpPathFn != nil {
		return c.ytdlpPathFn()
	}
	return YtDlpPath()
}
