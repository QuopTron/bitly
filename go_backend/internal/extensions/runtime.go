package extensions

import (
	"fmt"
	"os"
	"time"

	"github.com/dop251/goja"
)

// Runtime executes JS extensions in a sandboxed goja environment.
type Runtime struct {
	sandboxes map[string]*Sandbox
}

// NewRuntime creates a new extension runtime.
func NewRuntime() *Runtime {
	return &Runtime{sandboxes: make(map[string]*Sandbox)}
}

// Count returns the number of sandboxes currently loaded in the runtime.
func (r *Runtime) Count() int {
	return len(r.sandboxes)
}

// RunScript loads and executes a JS extension file.
func (r *Runtime) RunScript(info *ExtensionInfo, cfg RuntimeConfig, dataDir string) (map[string]interface{}, error) {
	data, err := os.ReadFile(info.Path)
	if err != nil {
		return nil, fmt.Errorf("ext: read %s: %w", info.ID, err)
	}
	return r.RunJS(string(data), info.ID, info.Name, cfg, dataDir)
}

// RunJS executes raw JS source in a sandboxed goja environment.
func (r *Runtime) RunJS(source, extID, extName string, cfg RuntimeConfig, dataDir string) (map[string]interface{}, error) {
	vm := goja.New()
	vm.SetFieldNameMapper(goja.TagFieldNameMapper("json", true))

	sandbox := &Sandbox{
		VM:      vm,
		Config:  cfg,
		Store:   NewStorage(dataDir, extID),
		ID:      extID,
		DataDir: dataDir,
		lockCh:  make(chan struct{}, 1),
	}

	// Register all sandbox APIs
	registerHTTP(sandbox)
	registerCrypto(sandbox)
	registerStorage(sandbox)
	registerFileOps(sandbox)
	registerMatching(sandbox)
	registerAuth(sandbox)
	registerGlobal(sandbox)
	registerSignedSession(sandbox)

	_ = vm.Set("__ext_id", extID)
	_ = vm.Set("__ext_name", extName)

	type result struct {
		val goja.Value
		err error
	}
	done := make(chan result, 1)

	go func() {
		defer func() {
			if rec := recover(); rec != nil {
				done <- result{err: fmt.Errorf("ext panic: %v", rec)}
			}
		}()
		val, err := vm.RunString(source)
		done <- result{val: val, err: err}
	}()

	timeout := time.Duration(cfg.TimeoutMs) * time.Millisecond
	select {
	case res := <-done:
		if res.err != nil {
			return nil, fmt.Errorf("ext %s: %w", extID, res.err)
		}
		if res.val != nil && res.val.Export() != nil {
			if obj, ok := res.val.Export().(map[string]interface{}); ok {
				r.sandboxes[extID] = sandbox
				return obj, nil
			}
		}
	case <-time.After(timeout):
		return nil, fmt.Errorf("ext %s: execution timeout (%dms)", extID, cfg.TimeoutMs)
	}

	r.sandboxes[extID] = sandbox
	return map[string]interface{}{}, nil
}
