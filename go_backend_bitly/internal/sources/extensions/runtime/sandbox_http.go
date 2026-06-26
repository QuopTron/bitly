package runtime

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

const maxExtensionHTTPResponseBytes = 16 << 20

type simpleCookieJar struct {
	cookies map[string][]*http.Cookie
}

func newSimpleCookieJar() *simpleCookieJar {
	return &simpleCookieJar{cookies: make(map[string][]*http.Cookie)}
}

func (j *simpleCookieJar) SetCookies(u *url.URL, cookies []*http.Cookie) {
	j.cookies[u.Host] = append(j.cookies[u.Host], cookies...)
}

func (j *simpleCookieJar) Cookies(u *url.URL) []*http.Cookie {
	return j.cookies[u.Host]
}

func validateDomain(urlStr string, mf *manifest.ExtensionManifest) error {
	parsed, err := url.Parse(urlStr)
	if err != nil {
		return fmt.Errorf("invalid URL: %w", err)
	}
	if parsed.Scheme == "" {
		return fmt.Errorf("invalid URL: scheme is required")
	}
	if parsed.Scheme != "https" && !(parsed.Scheme == "http" && mf != nil && mf.Permissions.AllowHTTP) {
		return fmt.Errorf("network access denied: only https is allowed")
	}
	if parsed.User != nil {
		return fmt.Errorf("invalid URL: embedded credentials are not allowed")
	}
	domain := parsed.Hostname()
	if domain == "" {
		return fmt.Errorf("invalid URL: hostname is required")
	}
	if isPrivateDomain(domain) {
		return fmt.Errorf("network access denied: private/local network '%s' not allowed", domain)
	}
	if mf != nil && !mf.IsDomainAllowed(domain) {
		return fmt.Errorf("network access denied: domain '%s' not in allowed list", domain)
	}
	return nil
}

func isPrivateDomain(host string) bool {
	host = strings.ToLower(strings.TrimSpace(host))
	if host == "" {
		return false
	}
	if host == "localhost" || strings.HasSuffix(host, ".local") {
		return true
	}
	if strings.HasPrefix(host, "127.") || strings.HasPrefix(host, "10.") ||
		strings.HasPrefix(host, "192.168.") || strings.HasPrefix(host, "172.16.") {
		return true
	}
	if host == "::1" || host == "0.0.0.0" {
		return true
	}
	return false
}

func readExtensionHTTPResponseBody(resp *http.Response) ([]byte, error) {
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxExtensionHTTPResponseBytes+1))
	if err != nil {
		return nil, err
	}
	if len(body) > maxExtensionHTTPResponseBytes {
		return nil, fmt.Errorf("response body exceeds %d byte limit", maxExtensionHTTPResponseBytes)
	}
	return body, nil
}

func (ler *loadedExtensionRuntime) registerHTTP() {
	httpObj := ler.vm.NewObject()
	httpObj.Set("get", ler.httpGet)
	httpObj.Set("post", ler.httpPost)
	httpObj.Set("put", ler.httpPut)
	httpObj.Set("delete", ler.httpDelete)
	httpObj.Set("patch", ler.httpPatch)
	httpObj.Set("request", ler.httpRequest)
	httpObj.Set("clearCookies", ler.httpClearCookies)
	ler.vm.Set("http", httpObj)
}

func (ler *loadedExtensionRuntime) doHTTPRequest(method, urlStr string, bodyStr string, headers map[string]string) goja.Value {
	req, err := http.NewRequest(method, urlStr, strings.NewReader(bodyStr))
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"error": err.Error(), "statusCode": 0, "ok": false, "body": ""})
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	if req.Header.Get("User-Agent") == "" {
		req.Header.Set("User-Agent", "Bitly-Extension/1.0")
	}
	if bodyStr != "" && req.Header.Get("Content-Type") == "" {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := ler.httpClient.Do(req)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"error": err.Error(), "statusCode": 0, "ok": false, "body": ""})
	}
	defer resp.Body.Close()
	body, err := readExtensionHTTPResponseBody(resp)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"error": err.Error(), "statusCode": resp.StatusCode, "ok": false, "body": ""})
	}
	respHeaders := make(map[string]interface{})
	for k, v := range resp.Header {
		if len(v) == 1 { respHeaders[k] = v[0] } else { respHeaders[k] = v }
	}
	return ler.vm.ToValue(map[string]interface{}{
		"statusCode": resp.StatusCode, "status": resp.StatusCode,
		"ok": resp.StatusCode >= 200 && resp.StatusCode < 300,
		"url": resp.Request.URL.String(), "body": string(body), "headers": respHeaders,
	})
}

func (ler *loadedExtensionRuntime) httpGet(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(map[string]interface{}{"error": "URL is required"}) }
	urlStr := call.Arguments[0].String()
	if err := validateDomain(urlStr, ler.manifest); err != nil { return ler.vm.ToValue(map[string]interface{}{"error": err.Error()}) }
	headers := extractHeaders(call, 1)
	return ler.doHTTPRequest("GET", urlStr, "", headers)
}

func (ler *loadedExtensionRuntime) httpPost(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(map[string]interface{}{"error": "URL is required"}) }
	urlStr := call.Arguments[0].String()
	if err := validateDomain(urlStr, ler.manifest); err != nil { return ler.vm.ToValue(map[string]interface{}{"error": err.Error()}) }
	bodyStr := extractBody(call, 1)
	headers := extractHeaders(call, 2)
	return ler.doHTTPRequest("POST", urlStr, bodyStr, headers)
}

func (ler *loadedExtensionRuntime) httpRequest(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(map[string]interface{}{"error": "URL is required"}) }
	urlStr := call.Arguments[0].String()
	if err := validateDomain(urlStr, ler.manifest); err != nil { return ler.vm.ToValue(map[string]interface{}{"error": err.Error()}) }
	method, bodyStr, headers := "GET", "", make(map[string]string)
	if len(call.Arguments) > 1 {
		if opts, ok := call.Arguments[1].Export().(map[string]interface{}); ok {
			if m, ok := opts["method"].(string); ok { method = strings.ToUpper(m) }
			if b, ok := opts["body"]; ok {
			switch v := b.(type) {
			case string: bodyStr = v
			case map[string]interface{}, []interface{}:
				jb, err := json.Marshal(v)
				if err == nil { bodyStr = string(jb) }
			default: bodyStr = fmt.Sprintf("%v", b)
			}
		}
			if h, ok := opts["headers"].(map[string]interface{}); ok {
				for k, v := range h { headers[k] = fmt.Sprintf("%v", v) }
			}
		}
	}
	return ler.doHTTPRequest(method, urlStr, bodyStr, headers)
}

func (ler *loadedExtensionRuntime) httpPut(call goja.FunctionCall) goja.Value {
	return ler.doHTTPMethodShortcut("PUT", call)
}
func (ler *loadedExtensionRuntime) httpDelete(call goja.FunctionCall) goja.Value {
	return ler.doHTTPMethodShortcut("DELETE", call)
}
func (ler *loadedExtensionRuntime) httpPatch(call goja.FunctionCall) goja.Value {
	return ler.doHTTPMethodShortcut("PATCH", call)
}

func (ler *loadedExtensionRuntime) doHTTPMethodShortcut(method string, call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(map[string]interface{}{"error": "URL is required"}) }
	urlStr := call.Arguments[0].String()
	if err := validateDomain(urlStr, ler.manifest); err != nil { return ler.vm.ToValue(map[string]interface{}{"error": err.Error()}) }
	bodyStr := extractBody(call, 1)
	headers := make(map[string]string)
	headerIdx := 2
	if method == "DELETE" { headerIdx = 1; bodyStr = "" }
	headers = extractHeaders(call, headerIdx)
	return ler.doHTTPRequest(method, urlStr, bodyStr, headers)
}

func (ler *loadedExtensionRuntime) httpClearCookies(call goja.FunctionCall) goja.Value {
	if jar, ok := ler.cookieJar.(*simpleCookieJar); ok {
		jar.cookies = make(map[string][]*http.Cookie)
		return ler.vm.ToValue(true)
	}
	return ler.vm.ToValue(false)
}

func extractHeaders(call goja.FunctionCall, idx int) map[string]string {
	headers := make(map[string]string)
	if len(call.Arguments) > idx && !goja.IsUndefined(call.Arguments[idx]) && !goja.IsNull(call.Arguments[idx]) {
		if h, ok := call.Arguments[idx].Export().(map[string]interface{}); ok {
			for k, v := range h { headers[k] = fmt.Sprintf("%v", v) }
		}
	}
	return headers
}

func extractBody(call goja.FunctionCall, idx int) string {
	if len(call.Arguments) > idx && !goja.IsUndefined(call.Arguments[idx]) && !goja.IsNull(call.Arguments[idx]) {
		arg := call.Arguments[idx].Export()
		switch v := arg.(type) {
		case string: return v
		case map[string]interface{}, []interface{}:
			b, err := json.Marshal(v)
			if err != nil { return "" }
			return string(b)
		default: return call.Arguments[idx].String()
		}
	}
	return ""
}
