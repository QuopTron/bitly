package extensions

import (
	"context"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// Los clientes HTTP compartidos (extHTTPClient/ytHTTPClient y sus helpers
// esHostYouTube/esHostGooglevideo/clienteHTTPExtPara/ytHTTPClientFor) viven en
// http_helpers_clients.go (splits de la sesión de desestructuración).

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
	// YouTube/InnerTube requests use uTLS fingerprinting + HTTP2 to bypass bot
	// detection (Standard Go TLS fingerprints are flagged by YouTube → 403,
	// and the API negotiates h2 regardless of ALPN). The googlevideo media CDN
	// is the opposite: signed URLs served over plain HTTP/1.1 — the uTLS/H2
	// client breaks there ("http2: frame too large"), so it uses the standard
	// DoH client.
	client := clienteHTTPExtPara()
	if esHostYouTube(url) && !esHostGooglevideo(url) {
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
		// Diagnostic: the ytmusic extension surfaces this as "bad response 0"
		// with no detail; log the real dial/TLS error so Android-only failures
		// (DNS, uTLS handshake) are visible in logcat.
		if esHostYouTube(url) {
			log.Printf("[ext-http] youtube fetch failed: %s -> %v", url, err)
		}
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

// checkDomain/errDomainBlocked/extError/toString viven en http_helpers_misc.go
// (verificarDominio/errDominioBloqueado/extError/toString) y en
// http_helpers.go se conservan solo las funciones de HTTP (doHTTP*).
