package runtime

import "github.com/dop251/goja"

func (r *ExtensionRuntime) HasMethod(extensionID, method string) bool {
	r.mu.RLock()
	extRuntime, ok := r.runtimes[extensionID]
	r.mu.RUnlock()
	if !ok {
		return false
	}

	methodFn := extRuntime.vm.Get("extension").ToObject(extRuntime.vm).Get(method)
	return methodFn != nil && !goja.IsUndefined(methodFn)
}

func (r *ExtensionRuntime) IsLoaded(extensionID string) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	_, ok := r.runtimes[extensionID]
	return ok
}

func (r *ExtensionRuntime) ListLoaded() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	ids := make([]string, 0, len(r.runtimes))
	for id := range r.runtimes {
		ids = append(ids, id)
	}
	return ids
}
