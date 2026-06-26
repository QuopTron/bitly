package runtime

import "github.com/dop251/goja"

func (ler *loadedExtensionRuntime) registerExtensionAPIs() {
	ler.registerHTTP()
	ler.registerFetch()
	ler.registerStorage()
	ler.registerCredentials()
	ler.registerFile()
	ler.registerAuth()
	ler.registerMatching()
	ler.registerFFmpeg()
	ler.registerUtils()
	ler.registerTextEncoder()
	ler.registerURLClass()

	ler.vm.Set("JSON", ler.vm.NewObject())
	jsonObj := ler.vm.Get("JSON").ToObject(ler.vm)
	jsonObj.Set("parse", ler.parseJSON)
	jsonObj.Set("stringify", ler.stringifyJSON)
}

// registerRegisterExtension injects the global registerExtension() function
// that extensions call to register their methods (getHomeFeed, search, etc.).
// It copies all properties from the passed object onto the global "extension" object.
func (ler *loadedExtensionRuntime) registerRegisterExtension() {
	ler.vm.Set("registerExtension", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) == 0 {
			return goja.Undefined()
		}
		extDef := call.Argument(0)
		if extDef == nil || goja.IsUndefined(extDef) || goja.IsNull(extDef) {
			return goja.Undefined()
		}
		extObj := extDef.ToObject(ler.vm)
		extension := ler.vm.NewObject()
		for _, key := range extObj.Keys() {
			extension.Set(key, extObj.Get(key))
		}
		ler.vm.Set("extension", extension)
		return goja.Undefined()
	})
}
