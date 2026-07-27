package httpclient

import (
	"bytes"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strings"
)

// Common Cloudflare challenge indicators in response bodies.
var cloudflareIndicators = []string{
	"cf-browser-verification",
	"challenge-platform",
	"__cf_chl_f_tk",
	"jschl_vc",
	"a[data-vivaldi-spatnav-clickable]",
	"Just a moment...",
}

// IsCloudflareChallenge returns true if the response appears to be a
// Cloudflare challenge page (CAPTCHA or JS challenge).
func IsCloudflareChallenge(resp *http.Response) bool {
	if resp == nil {
		return false
	}
	if ct := resp.Header.Get("Content-Type"); !strings.HasPrefix(ct, "text/html") {
		return false
	}
	if server := resp.Header.Get("Server"); strings.Contains(server, "cloudflare") {
		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		resp.Body = io.NopCloser(bytes.NewReader(body))
		if err != nil {
			return false
		}
		bodyStr := string(body)
		for _, indicator := range cloudflareIndicators {
			if strings.Contains(bodyStr, indicator) {
				return true
			}
		}
	}
	return false
}

// HasCFClearance checks if a cookie jar contains a valid cf_clearance cookie
// for the given domain.
func HasCFClearance(jar http.CookieJar, domain string) bool {
	if jar == nil {
		return false
	}
	u := &url.URL{Scheme: "https", Host: domain}
	for _, c := range jar.Cookies(u) {
		if strings.HasPrefix(c.Name, "cf_clearance") && c.Value != "" {
			return true
		}
	}
	return false
}

// CloudflareError is returned when a request is blocked by Cloudflare.
type CloudflareError struct {
	Domain string
	Status int
}

func (e *CloudflareError) Error() string {
	return "cloudflare challenge: " + e.Domain
}

// IsCloudflareBlocked returns true if the error is a Cloudflare challenge.
func IsCloudflareBlocked(err error) bool {
	if err == nil {
		return false
	}
	var cfErr *CloudflareError
	return errors.As(err, &cfErr)
}
