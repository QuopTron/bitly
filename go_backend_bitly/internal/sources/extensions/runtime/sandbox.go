package runtime

import (
	"encoding/base64"
	"fmt"
	"strings"

	"github.com/dop251/goja"
)

func registerPolyfills(vm *goja.Runtime) {
	vm.Set("atob", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 1 {
			return vm.ToValue("")
		}
		input := call.Arguments[0].String()
		decoded, err := base64.StdEncoding.DecodeString(input)
		if err != nil {
			decoded, err = base64.URLEncoding.DecodeString(input)
			if err != nil {
				return vm.ToValue("")
			}
		}
		return vm.ToValue(string(decoded))
	})
	vm.Set("btoa", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 1 {
			return vm.ToValue("")
		}
		return vm.ToValue(base64.StdEncoding.EncodeToString([]byte(call.Arguments[0].String())))
	})

	_, _ = vm.RunString(`
		if (typeof setTimeout !== 'function') {
			setTimeout = function(fn, ms) { if (typeof fn === 'function') fn(); return 0; };
		}
		if (typeof clearTimeout !== 'function') { clearTimeout = function(id) {}; }
		if (typeof setInterval !== 'function') { setInterval = function() { return 0; }; }
		if (typeof clearInterval !== 'function') { clearInterval = function(id) {}; }
	`)
}

func registerConsole(vm *goja.Runtime, extensionID string) {
	logFn := func(call goja.FunctionCall) goja.Value {
		parts := make([]string, len(call.Arguments))
		for i, arg := range call.Arguments {
			parts[i] = fmt.Sprintf("%v", arg.Export())
		}
		msg := strings.Join(parts, " ")
		fmt.Printf("[Extension:%s] %s\n", extensionID, msg)
		return goja.Undefined()
	}

	consoleObj := vm.NewObject()
	consoleObj.Set("log", logFn)
	consoleObj.Set("info", logFn)
	consoleObj.Set("warn", func(call goja.FunctionCall) goja.Value {
		parts := make([]string, len(call.Arguments))
		for i, arg := range call.Arguments {
			parts[i] = fmt.Sprintf("%v", arg.Export())
		}
		fmt.Printf("[Extension:%s:WARN] %s\n", extensionID, strings.Join(parts, " "))
		return goja.Undefined()
	})
	consoleObj.Set("error", func(call goja.FunctionCall) goja.Value {
		parts := make([]string, len(call.Arguments))
		for i, arg := range call.Arguments {
			parts[i] = fmt.Sprintf("%v", arg.Export())
		}
		fmt.Printf("[Extension:%s:ERROR] %s\n", extensionID, strings.Join(parts, " "))
		return goja.Undefined()
	})
	consoleObj.Set("debug", logFn)
	vm.Set("console", consoleObj)
}
