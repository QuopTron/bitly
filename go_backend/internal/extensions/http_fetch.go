package extensions

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/dop251/goja"
)

// abortResp builds the fetch response object extensions see on failure, so JS
// code that checks res.ok / res.status behaves the same as a failed fetch.
func abortResp(vm *goja.Runtime, url, msg string) goja.Value {
	respObj := vm.NewObject()
	respObj.Set("ok", false)
	respObj.Set("status", 0)
	respObj.Set("body", msg)
	respObj.Set("json", func() interface{} { return nil })
	respObj.Set("text", func() string { return msg })
	h := vm.NewObject()
	h.Set("get", func(call goja.FunctionCall) goja.Value {
		return goja.Undefined()
	})
	respObj.Set("headers", h)
	return respObj
}

// registerFetch adds a fetch(url, opts) API compatible with the Fetch API.
func registerFetch(vm *goja.Runtime) {
	vm.Set("fetch", func(call goja.FunctionCall) goja.Value {
		url := call.Argument(0).String()
		opts := map[string]interface{}{}
		if o := call.Argument(1).Export(); o != nil {
			if m, ok := o.(map[string]interface{}); ok {
				opts = m
			}
		}

		method := "GET"
		if m, ok := opts["method"].(string); ok {
			method = m
		}
		reqBody := ""
		if b, ok := opts["body"].(string); ok {
			reqBody = b
		}
		headers := map[string]string{}
		if h, ok := opts["headers"].(map[string]interface{}); ok {
			for k, v := range h {
				headers[k] = toString(v)
			}
		}

		// Honor the JS AbortController signal: the extension's safeFetch wraps
		// fetch in a timeout that calls controller.abort(). The bridge runs
		// synchronously (no event loop mid-call), so an abort fired BEFORE this
		// request starts must fail fast, and requests carrying a signal get a
		// hard deadline instead of silently running the full 30s client
		// timeout (which made a "15s timeout" JS call block 30s×retries and
		// hang every later call to the sandbox).
		var resp *http.Response
		var bodyStr string
		var err error
		if sig, hasSig := opts["signal"].(map[string]interface{}); hasSig && sig != nil {
			if aborted, ok := sig["aborted"].(bool); ok && aborted {
				return abortResp(vm, url, "aborted")
			}
			// Extension timeouts (CONFIG.fetchTimeoutMs) are a few seconds; a
			// signaled request must never outlive that by much.
			resp, bodyStr, err = doHTTPWithTimeout(method, url, reqBody, headers, 20*time.Second)
		} else {
			resp, bodyStr, err = doHTTP(method, url, reqBody, headers)
		}

		if err != nil {
			return abortResp(vm, url, err.Error())
		}

		respObj := vm.NewObject()
		respObj.Set("ok", resp.StatusCode >= 200 && resp.StatusCode < 300)
		respObj.Set("status", resp.StatusCode)
		respObj.Set("body", bodyStr)
		respObj.Set("json", func() interface{} {
			var parsed interface{}
			json.Unmarshal([]byte(bodyStr), &parsed)
			return parsed
		})
		respObj.Set("text", func() string {
			return bodyStr
		})

		h := vm.NewObject()
		for k := range resp.Header {
			kCopy := k
			h.Set(kCopy, resp.Header.Get(k))
		}
		h.Set("get", func(call goja.FunctionCall) goja.Value {
			return vm.ToValue(resp.Header.Get(call.Argument(0).String()))
		})
		respObj.Set("headers", h)

		return respObj
	})
}
