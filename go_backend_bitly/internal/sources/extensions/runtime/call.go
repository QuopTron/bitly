package runtime

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/dop251/goja"
)

func (r *ExtensionRuntime) CallMethod(extensionID, method string, args ...interface{}) (*CallResult, error) {
	r.mu.RLock()
	extRuntime, ok := r.runtimes[extensionID]
	r.mu.RUnlock()
	if !ok {
		return nil, fmt.Errorf("extension %q not loaded in runtime", extensionID)
	}

	vm := extRuntime.vm

	extVal := vm.Get("extension")
	if extVal == nil || goja.IsUndefined(extVal) {
		return nil, fmt.Errorf("extension %q has no 'extension' object", extensionID)
	}
	extObj := extVal.ToObject(vm)

	methodFn := extObj.Get(method)
	if methodFn == nil || goja.IsUndefined(methodFn) {
		return nil, fmt.Errorf("extension %q does not implement '%s'", extensionID, method)
	}

	callable, ok := goja.AssertFunction(methodFn)
	if !ok {
		return nil, fmt.Errorf("extension %q.%s is not a function", extensionID, method)
	}

	gojaArgs := make([]goja.Value, len(args))
	for i, arg := range args {
		gojaArgs[i] = vm.ToValue(arg)
	}

	type callResult struct {
		value goja.Value
		err   error
	}

	resultCh := make(chan callResult, 1)
	go func() {
		defer func() {
			if rec := recover(); rec != nil {
				resultCh <- callResult{err: fmt.Errorf("panic in extension %q.%s: %v", extensionID, method, rec)}
			}
		}()
		val, err := callable(goja.Undefined(), gojaArgs...)
		resultCh <- callResult{value: val, err: err}
	}()

	select {
	case res := <-resultCh:
		if res.err != nil {
			return nil, fmt.Errorf("extension %q.%s failed: %w", extensionID, method, res.err)
		}
		if res.value == nil || goja.IsUndefined(res.value) || goja.IsNull(res.value) {
			return &CallResult{Value: nil, RawJSON: "null"}, nil
		}
		exported := res.value.Export()
		jsonBytes, _ := json.Marshal(exported)
		return &CallResult{
			Value:   exported,
			RawJSON: string(jsonBytes),
		}, nil

	case <-time.After(DefaultJSTimeout):
		return nil, fmt.Errorf("extension %q.%s timed out after %v", extensionID, method, DefaultJSTimeout)
	}
}

func (r *ExtensionRuntime) UnloadExtension(extensionID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.runtimes, extensionID)
}
