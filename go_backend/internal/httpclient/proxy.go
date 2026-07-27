package httpclient

import (
	"math/rand"
	"net/url"
	"sync"
)

// ProxyRotator manages a pool of proxies for rotation.
type ProxyRotator struct {
	mu      sync.Mutex
	proxies []*url.URL
	index   int
}

// NewProxyRotator creates a rotator from a list of proxy URLs.
// Each URL should be in the form: http://user:pass@host:port
func NewProxyRotator(proxyURLs []string) (*ProxyRotator, error) {
	parsed := make([]*url.URL, 0, len(proxyURLs))
	for _, p := range proxyURLs {
		u, err := url.Parse(p)
		if err != nil {
			return nil, err
		}
		parsed = append(parsed, u)
	}
	return &ProxyRotator{proxies: parsed}, nil
}

// Next returns the next proxy URL in round-robin order.
func (pr *ProxyRotator) Next() *url.URL {
	pr.mu.Lock()
	defer pr.mu.Unlock()
	if len(pr.proxies) == 0 {
		return nil
	}
	pr.index = (pr.index + 1) % len(pr.proxies)
	return pr.proxies[pr.index]
}

// Random returns a random proxy URL from the pool.
func (pr *ProxyRotator) Random() *url.URL {
	pr.mu.Lock()
	defer pr.mu.Unlock()
	if len(pr.proxies) == 0 {
		return nil
	}
	return pr.proxies[rand.Intn(len(pr.proxies))]
}

// Add appends a proxy to the pool.
func (pr *ProxyRotator) Add(rawURL string) error {
	u, err := url.Parse(rawURL)
	if err != nil {
		return err
	}
	pr.mu.Lock()
	pr.proxies = append(pr.proxies, u)
	pr.mu.Unlock()
	return nil
}

// Len returns the number of proxies in the pool.
func (pr *ProxyRotator) Len() int {
	pr.mu.Lock()
	defer pr.mu.Unlock()
	return len(pr.proxies)
}
