package extensions

import (
	"os"
	"path/filepath"

	"github.com/dop251/goja"
)

// registerFileOps adds sandboxed file operations to the JS runtime.
func registerFileOps(s *Sandbox) {
	if !s.Config.EnableFS {
		return
	}
	vm := s.VM
	fileObj := vm.NewObject()

	fileObj.Set("read", func(call goja.FunctionCall) goja.Value {
		path := call.Argument(0).String()
		fullPath, err := resolvePath(s, path)
		if err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		data, err := os.ReadFile(fullPath)
		if err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		return vm.ToValue(string(data))
	})

	fileObj.Set("write", func(call goja.FunctionCall) goja.Value {
		path := call.Argument(0).String()
		data := call.Argument(1).String()
		fullPath, err := resolvePath(s, path)
		if err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		if err := os.WriteFile(fullPath, []byte(data), 0644); err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		return goja.Undefined()
	})

	registerFileReadOps(s, fileObj)
	registerFileDownload(s, fileObj)

	vm.Set("file", fileObj)
}
