package httpclient

import (
	"fmt"
	"math/rand"
	"net/url"
	"strings"
	"time"
)

const (
	DefaultTimeout    = 60 * time.Second
	DownloadTimeout   = 24 * time.Hour
	SongLinkTimeout   = 30 * time.Second
	DefaultMaxRetries = 3
	DefaultRetryDelay = 1 * time.Second
)

func UserAgentForURL(u *url.URL) string {
	if u == nil {
		return getRandomUserAgent()
	}
	host := strings.ToLower(strings.TrimSpace(u.Hostname()))
	if host == "api.zarz.moe" {
		return appUserAgent()
	}
	return getRandomUserAgent()
}

var appUserAgent = func() string {
	return "Bitly/1.0"
}

func getRandomUserAgent() string {
	chromeVersion := rand.Intn(26) + 120
	chromeBuild := rand.Intn(1500) + 6000
	chromePatch := rand.Intn(200) + 100
	return fmt.Sprintf(
		"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/%d.0.%d.%d Safari/537.36",
		chromeVersion, chromeBuild, chromePatch,
	)
}
