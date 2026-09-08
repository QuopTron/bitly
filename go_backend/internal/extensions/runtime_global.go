package extensions

import (
	"github.com/dop251/goja"
)

// registerGlobal instala las APIs globales que las extensiones JS esperan:
// registerExtension (callbacks), URL/Intl (polyfills mínimos) y los objetos
// gobackend/utils (ver registrarGlobalGobackend y registrarGlobalUtils).
func registerGlobal(sandbox *Sandbox) {
	vm := sandbox.VM

	// registerExtension(callbacks) - stores extension callbacks as global functions
	_ = vm.Set("registerExtension", func(call goja.FunctionCall) goja.Value {
		obj := call.Argument(0).Export()
		if obj == nil {
			return goja.Undefined()
		}
		if extObj, ok := obj.(map[string]interface{}); ok {
			for name, fn := range extObj {
				if _, isFn := goja.AssertFunction(vm.ToValue(fn)); isFn {
					_ = vm.Set(name, fn)
				}
			}
		}
		return goja.Undefined()
	})

	// URL constructor - polyfill minimo para parsear URLs
	_ = vm.Set("URL", constructorURLSandbox(vm))

	// Minimal Intl polyfill for Amazon extension
	intlObj := vm.NewObject()
	dtfObj := vm.NewObject()
	_ = dtfObj.Set("resolvedOptions", func() map[string]interface{} {
		return map[string]interface{}{
			"timeZone": "UTC",
		}
	})
	_ = intlObj.Set("DateTimeFormat", func(call goja.FunctionCall) goja.Value {
		return vm.ToValue(dtfObj)
	})
	_ = vm.Set("Intl", intlObj)

	registrarGlobalGobackend(vm)
	registrarGlobalUtils(vm)
}
