package extensions

import (
	"fmt"
	"log"
	"strings"

	"github.com/dop251/goja"
)

// registerConsoleObject creates the log/console object for JS sandbox.
func registerConsoleObject(vm *goja.Runtime, id string) {
	logObj := vm.NewObject()

	logFn := func(level string, args []goja.Value) {
		parts := make([]string, len(args))
		for i, arg := range args {
			if arg != nil && !goja.IsUndefined(arg) && !goja.IsNull(arg) {
				parts[i] = fmt.Sprint(arg.Export())
			} else {
				parts[i] = ""
			}
		}
		log.Printf("[%s][%s] %s", id, level, strings.Join(parts, " "))
	}

	logObj.Set("info", func(call goja.FunctionCall) goja.Value {
		logFn("INFO", call.Arguments)
		return goja.Undefined()
	})
	logObj.Set("debug", func(call goja.FunctionCall) goja.Value {
		logFn("DEBUG", call.Arguments)
		return goja.Undefined()
	})
	logObj.Set("warn", func(call goja.FunctionCall) goja.Value {
		logFn("WARN", call.Arguments)
		return goja.Undefined()
	})
	logObj.Set("error", func(call goja.FunctionCall) goja.Value {
		logFn("ERROR", call.Arguments)
		return goja.Undefined()
	})

	vm.Set("log", logObj)
	vm.Set("console", logObj)
}
