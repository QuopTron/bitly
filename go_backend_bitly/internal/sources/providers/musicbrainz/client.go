package musicbrainz

import (
	"sync"
	"time"

	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

const (
	apiBase       = "https://musicbrainz.org/ws/2"
	requestWindow = 1100 * time.Millisecond
	cooldownDur   = 5 * time.Second
	maxRetries    = 3
	userAgent     = "Bitly/4.5.1 ( https://github.com/zarz/Bitly_android )"
)

type inFlightKey struct {
	isrc      string
	queryType string
}

type inFlightResult struct {
	result string
	err    error
}

type Client struct {
	rl       *httpclient.RateLimiter
	mu       sync.Mutex
	cooldown time.Time
	inflight map[inFlightKey]chan inFlightResult
}

var (
	globalClient     *Client
	globalClientOnce sync.Once
)

func GetClient() *Client {
	globalClientOnce.Do(func() {
		globalClient = &Client{
			rl:       httpclient.NewRateLimiter(1, requestWindow),
			inflight: make(map[inFlightKey]chan inFlightResult),
		}
	})
	return globalClient
}

func (c *Client) waitForCooldown() {
	c.mu.Lock()
	now := time.Now()
	if now.Before(c.cooldown) {
		waitDur := c.cooldown.Sub(now)
		c.mu.Unlock()
		time.Sleep(waitDur)
		return
	}
	c.mu.Unlock()
}

func (c *Client) enterCooldown() {
	c.mu.Lock()
	c.cooldown = time.Now().Add(cooldownDur)
	c.mu.Unlock()
}
