package runtime

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/dop251/goja"
)

func (ler *loadedExtensionRuntime) registerFetch() {
	ler.vm.Set("fetch", ler.fetchPolyfill)
}

func (ler *loadedExtensionRuntime) fetchPolyfill(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 {
		return ler.createFetchError("URL is required")
	}
	urlStr := call.Arguments[0].String()
	if err := validateDomain(urlStr, ler.manifest); err != nil {
		return ler.createFetchError(err.Error())
	}
	method := "GET"
	var bodyStr string
	headers := make(map[string]string)
	if len(call.Arguments) > 1 && !goja.IsUndefined(call.Arguments[1]) && !goja.IsNull(call.Arguments[1]) {
		if opts, ok := call.Arguments[1].Export().(map[string]interface{}); ok {
			if m, ok := opts["method"].(string); ok { method = strings.ToUpper(m) }
			if b, ok := opts["body"]; ok && b != nil {
				switch v := b.(type) {
				case string: bodyStr = v
				default: bodyStr = fmt.Sprintf("%v", v)
				}
			}
			if h, ok := opts["headers"].(map[string]interface{}); ok {
				for k, v := range h { headers[k] = fmt.Sprintf("%v", v) }
			}
		}
	}
	var reqBody io.Reader
	if bodyStr != "" { reqBody = strings.NewReader(bodyStr) }
	req, err := http.NewRequest(method, urlStr, reqBody)
	if err != nil { return ler.createFetchError(err.Error()) }
	for k, v := range headers { req.Header.Set(k, v) }
	if req.Header.Get("User-Agent") == "" { req.Header.Set("User-Agent", "Bitly-Extension/1.0") }
	if bodyStr != "" && req.Header.Get("Content-Type") == "" { req.Header.Set("Content-Type", "application/json") }
	resp, err := ler.httpClient.Do(req)
	if err != nil { return ler.createFetchError(err.Error()) }
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil { return ler.createFetchError(err.Error()) }
	respHeaders := make(map[string]interface{})
	for k, v := range resp.Header {
		if len(v) == 1 { respHeaders[k] = v[0] } else { respHeaders[k] = v }
	}
	responseObj := ler.vm.NewObject()
	responseObj.Set("ok", resp.StatusCode >= 200 && resp.StatusCode < 300)
	responseObj.Set("status", resp.StatusCode)
	responseObj.Set("statusText", http.StatusText(resp.StatusCode))
	responseObj.Set("headers", respHeaders)
	responseObj.Set("url", resp.Request.URL.String())
	bodyString := string(body)
	responseObj.Set("text", func(call goja.FunctionCall) goja.Value {
		return ler.vm.ToValue(bodyString)
	})
	responseObj.Set("json", func(call goja.FunctionCall) goja.Value {
		var result interface{}
		if err := json.Unmarshal(body, &result); err != nil { return goja.Undefined() }
		return ler.vm.ToValue(result)
	})
	responseObj.Set("arrayBuffer", func(call goja.FunctionCall) goja.Value {
		byteArray := make([]interface{}, len(body))
		for i, b := range body { byteArray[i] = int(b) }
		return ler.vm.ToValue(byteArray)
	})
	return responseObj
}

func (ler *loadedExtensionRuntime) createFetchError(message string) goja.Value {
	errorObj := ler.vm.NewObject()
	errorObj.Set("ok", false)
	errorObj.Set("status", 0)
	errorObj.Set("statusText", "Network Error")
	errorObj.Set("error", message)
	errorObj.Set("text", func(call goja.FunctionCall) goja.Value { return ler.vm.ToValue("") })
	errorObj.Set("json", func(call goja.FunctionCall) goja.Value { return goja.Undefined() })
	return errorObj
}
