package extensions

import (
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
	client := extHTTPClientFor()
	req, err := http.NewRequest(method, url, strings.NewReader(body))
	if err != nil {
		return nil, "", err
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	if req.Header.Get("User-Agent") == "" {
		req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, "", err
	}
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
