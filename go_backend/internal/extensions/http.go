package extensions

import (
	"net/http"

	"github.com/dop251/goja"
)

// registerHTTP adds a fetch-like HTTP API to the JS sandbox.
func registerHTTP(s *Sandbox) {
	if !s.Config.EnableNetwork {
		return
	}
	vm := s.VM
	httpObj := vm.NewObject()

	httpObj.Set("get", func(call goja.FunctionCall) goja.Value {
		url := call.Argument(0).String()
		if err := checkDomain(s, url); err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		headers := extractHeaders(call.Argument(1))
		return doHTTPCompat(vm, "GET", url, "", headers)
	})

	httpObj.Set("post", func(call goja.FunctionCall) goja.Value {
		url := call.Argument(0).String()
		body := call.Argument(1).String()
		if err := checkDomain(s, url); err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		headers := extractHeaders(call.Argument(2))
		return doHTTPCompat(vm, "POST", url, body, headers)
	})

	httpObj.Set("put", func(call goja.FunctionCall) goja.Value {
		url := call.Argument(0).String()
		body := call.Argument(1).String()
		if err := checkDomain(s, url); err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		headers := extractHeaders(call.Argument(2))
		return doHTTPCompat(vm, "PUT", url, body, headers)
	})

	httpObj.Set("head", func(call goja.FunctionCall) goja.Value {
		if err := checkDomain(s, call.Argument(0).String()); err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		return doHTTPCompat(vm, "HEAD", call.Argument(0).String(), "", nil)
	})

	httpObj.Set("statusCode", func(call goja.FunctionCall) goja.Value {
		code := call.Argument(0).ToInteger()
		return vm.ToValue(http.StatusText(int(code)))
	})

	vm.Set("http", httpObj)
	registerFetch(vm)
}
