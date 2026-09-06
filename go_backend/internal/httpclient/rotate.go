package httpclient

import (
	"math/rand"
	"sync"
)

// userAgents is a pool of real-world browser User-Agent strings.
var userAgents = []string{
	// Chrome 131 on Windows
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
	// Chrome 131 on macOS
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
	// Firefox 133 on Windows
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:133.0) Gecko/20100101 Firefox/133.0",
	// Firefox 133 on macOS
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:133.0) Gecko/20100101 Firefox/133.0",
	// Safari 18 on macOS
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15",
	// Safari 18 on iOS
	"Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1",
	// Edge 131 on Windows
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0",
	// Chrome 131 on Android
	"Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36",
}

var (
	uaMu    sync.Mutex
	uaIndex int
)

// NextUserAgent returns a User-Agent from the pool in round-robin order.
func NextUserAgent() string {
	uaMu.Lock()
	defer uaMu.Unlock()
	uaIndex = (uaIndex + 1) % len(userAgents)
	return userAgents[uaIndex]
}

// RandomUserAgent returns a random User-Agent from the pool.
func RandomUserAgent() string {
	return userAgents[rand.Intn(len(userAgents))]
}

// UserAgentCount returns the number of available User-Agents.
func UserAgentCount() int {
	return len(userAgents)
}
