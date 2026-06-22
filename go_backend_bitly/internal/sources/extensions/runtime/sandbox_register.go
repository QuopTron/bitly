package runtime

func (ler *loadedExtensionRuntime) registerExtensionAPIs() {
	ler.registerHTTP()
	ler.registerFetch()
	ler.registerStorage()
	ler.registerCredentials()
	ler.registerFile()
	ler.registerAuth()
	ler.registerMatching()
	ler.registerUtils()
	ler.registerTextEncoder()
	ler.registerURLClass()

	ler.vm.Set("JSON", ler.vm.NewObject())
	jsonObj := ler.vm.Get("JSON").ToObject(ler.vm)
	jsonObj.Set("parse", ler.parseJSON)
	jsonObj.Set("stringify", ler.stringifyJSON)
}
