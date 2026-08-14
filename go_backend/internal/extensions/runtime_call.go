package extensions

import (
	"fmt"

	"github.com/dop251/goja"
)

// CallMethod calls an exported function from a loaded extension.
func (r *Runtime) CallMethod(extID, method string, args ...interface{}) (ret interface{}, callErr error) {
	// Recover from JS panics so they don't crash the app
	defer func() {
		if rec := recover(); rec != nil {
			callErr = fmt.Errorf("ext %s: %s panic: %v", extID, method, rec)
		}
	}()

	sandbox, ok := r.sandboxes[extID]
	if !ok {
		return nil, fmt.Errorf("ext %s not loaded", extID)
	}

	// goja is not thread-safe: a background download goroutine and a bridge-
	// thread search can hit the same extension at the same time. Serialize per
	// sandbox so concurrent calls to one extension never race on its VM.
	sandbox.Mu.Lock()
	defer sandbox.Mu.Unlock()

	fn := sandbox.VM.Get(method)
	if fn == nil || goja.IsUndefined(fn) {
		return nil, fmt.Errorf("ext %s: method %s not found", extID, method)
	}

	fnCall, isFunc := goja.AssertFunction(fn)
	if !isFunc {
		return nil, fmt.Errorf("ext %s: %s is not callable", extID, method)
	}

	jsArgs := make([]goja.Value, len(args))
	for i, arg := range args {
		jsArgs[i] = sandbox.VM.ToValue(arg)
	}

	result, err := fnCall(goja.Undefined(), jsArgs...)
	if err != nil {
		return nil, fmt.Errorf("ext %s: %s call failed: %w", extID, method, err)
	}
	if result != nil && !goja.IsUndefined(result) && !goja.IsNull(result) {
		return result.Export(), nil
	}
	return nil, nil
}

// Sandbox returns the sandbox for a loaded extension.
func (r *Runtime) Sandbox(extID string) *Sandbox {
	return r.sandboxes[extID]
}

// Close cleans up all sandboxes.
func (r *Runtime) Close() {
	for id, s := range r.sandboxes {
		s.Mu.Lock()
		s.VM.ClearInterrupt()
		s.Mu.Unlock()
		delete(r.sandboxes, id)
	}
}
