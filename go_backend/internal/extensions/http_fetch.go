package extensions

import (
	"encoding/json"

	"github.com/dop251/goja"
)

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

		resp, bodyStr, err := doHTTP(method, url, reqBody, headers)

		respObj := vm.NewObject()
		if err != nil {
			respObj.Set("ok", false)
			respObj.Set("status", 0)
			respObj.Set("body", err.Error())
			respObj.Set("json", func() interface{} { return nil })
			respObj.Set("text", func() string { return err.Error() })
			h := vm.NewObject()
			h.Set("get", func(call goja.FunctionCall) goja.Value {
				return goja.Undefined()
			})
			respObj.Set("headers", h)
			return respObj
		}

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
