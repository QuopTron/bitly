package extensions

import (
	"context"
	"io"
	"net/http"
	"net/http/cookiejar"
	"strings"
	"sync"
	"time"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// extHTTPClient is the shared HTTP client used by extension fetch()/http.*
// calls. It enables HTTP/2 and keeps a persistent cookie jar so providers like
// amazon that maintain session cookies across requests see them — mirroring the
// reference SpotiFLAC runtime, where a per-extension cookie jar keeps the
// anonymous web session alive so search/feed don't fall back to a login
// DialogTemplate (which parses to zero results).
var (
	extHTTPClientOnce sync.Once
	extHTTPClient     *http.Client
)

// YouTube domains that require uTLS fingerprinting to avoid 403 bot-gate.
var youtubeHosts = map[string]bool{
	"www.youtube.com":   true,
	"youtube.com":       true,
	"ytimg.com":         true,
	"googlevideo.com":   true,
	"youtu.be":          true,
	"music.youtube.com": true,
}

func isYouTubeHost(url string) bool {
	for host := range youtubeHosts {
		if strings.Contains(url, host) {
			return true
		}
	}
	return false
}

// extHTTPClientFor returns the shared, lazily-initialized extension HTTP
// client with a persistent cookie jar.
func extHTTPClientFor() *http.Client {
	extHTTPClientOnce.Do(func() {
		jar, _ := cookiejar.New(nil)
		transport := &http.Transport{
			DialContext:         httpclient.NewDoHDialContext(),
			ForceAttemptHTTP2:   true,
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 10,
			IdleConnTimeout:     90 * time.Second,
			TLSHandshakeTimeout: 10 * time.Second,
			DisableCompression:  true,
		}
		extHTTPClient = &http.Client{
			Timeout:   30 * time.Second,
			Transport: transport,
			Jar:       jar,
		}
	})
	return extHTTPClient
}

// ytHTTPClient is a separate HTTP client for YouTube/InnerTube requests that
// uses uTLS fingerprinting to mimic a real Chrome browser TLS handshake.
// YouTube bot-gates IPs with a Go TLS fingerprint → 403; uTLS solves this.
var (
	ytHTTPClientOnce sync.Once
	ytHTTPClient     *http.Client
)

func ytHTTPClientFor() *http.Client {
	ytHTTPClientOnce.Do(func() {
		jar, _ := cookiejar.New(nil)
		// uTLS dialer mimics Chrome's TLS fingerprint to bypass YouTube bot detection.
		dialFn := httpclient.NewUTLSDialer(httpclient.FingerprintChrome)
		transport := httpclient.NewTransport(httpclient.Config{
			Timeout:             30 * time.Second,
			KeepAlive:           30 * time.Second,
			MaxIdleConns:        50,
			MaxIdleConnsPerHost: 10,
			FollowRedirects:     true,
		}, dialFn)
		// Disable Go's stdlib TLS layer — uTLS handles it.
		transport.TLSClientConfig = nil
		ytHTTPClient = &http.Client{
			Timeout:   30 * time.Second,
			Transport: transport,
			Jar:       jar,
		}
	})
	return ytHTTPClient
}

// doHTTPCompat returns the old-style {status, body, headers} object.
func doHTTPCompat(vm *goja.Runtime, method, url, body string, headers map[string]string) goja.Value {
	resp, bodyStr, err := doHTTP(method, url, body, headers)
	result := vm.NewObject()
	if err != nil {
		result.Set("status", 0)
		result.Set("statusCode", 0)
		result.Set("ok", false)
		result.Set("body", "")
		result.Set("error", err.Error())
		return result
	}
	result.Set("status", resp.StatusCode)
	result.Set("statusCode", resp.StatusCode)
	result.Set("ok", resp.StatusCode >= 200 && resp.StatusCode < 300)
	result.Set("body", bodyStr)
	result.Set("headers", resp.Header)
	if resp.Request != nil && resp.Request.URL != nil {
		result.Set("url", resp.Request.URL.String())
	}
	return result
}

func doHTTP(method, url, body string, headers map[string]string) (*http.Response, string, error) {
	return doHTTPWithTimeout(method, url, body, headers, 30*time.Second)
}

// doHTTPWithTimeout performs a single request bounded by [timeout], regardless
// of the shared client's longer timeout. Used for fetch() calls that carry a JS
// AbortController signal, so an extension's declared timeout is respected even
// though the bridge runs synchronously and can't process the abort mid-call.
func doHTTPWithTimeout(method, url, body string, headers map[string]string, timeout time.Duration) (*http.Response, string, error) {
	// A dead gateway host (api.zarz.moe 522 storm etc.) must fail fast —
	// before the request is even built — so the per-track resolution walk
	// doesn't wait out the gateway/HTTP timeout on every attempt.
	if httpclient.BreakerBlocked(url) {
		req, _ := http.NewRequest(method, url, nil)
		return httpclient.SyntheticGatewayResponse(req), "", nil
	}
	// YouTube/InnerTube requests use uTLS fingerprinting to bypass bot detection.
	// Standard Go TLS fingerprints are flagged by YouTube → 403.
	client := extHTTPClientFor()
	if isYouTubeHost(url) {
		client = ytHTTPClientFor()
	}
	req, err := http.NewRequest(method, url, strings.NewReader(body))
	if err != nil {
		return nil, "", err
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	req = req.WithContext(ctx)

	for k, v := range headers {
		req.Header.Set(k, v)
	}
	if req.Header.Get("User-Agent") == "" {
		req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")
	}

	resp, err := client.Do(req)
	if err != nil {
		httpclient.BreakerRecord(url, 0, err)
		return nil, "", err
	}
	httpclient.BreakerRecord(url, resp.StatusCode, nil)
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, "", err
	}
	return resp, string(respBody), nil
}

func extractHeaders(v goja.Value) map[string]string {
	if v == nil || goja.IsUndefined(v) || goja.IsNull(v) {
		return nil
	}
	obj := v.ToObject(nil)
	if obj == nil {
		return nil
	}
	return ToStringMap(obj)
}

func checkDomain(s *Sandbox, url string) error {
	if len(s.Config.AllowedDomains) == 0 {
		return nil
	}
	for _, domain := range s.Config.AllowedDomains {
		if strings.Contains(url, domain) {
			return nil
		}
	}
	return errDomainBlocked(url)
}

func errDomainBlocked(url string) error {
	return &extError{msg: "domain not allowed: " + url}
}

type extError struct{ msg string }

func (e *extError) Error() string { return e.msg }

func toString(v interface{}) string {
	if v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}
