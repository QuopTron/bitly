package extensions

import (
	"encoding/base64"
	"fmt"
	"io"
	"os"

	"github.com/dop251/goja"
)

func registerFileReadOps(s *Sandbox, fileObj *goja.Object) {
	vm := s.VM

	fileObj.Set("readBytes", func(call goja.FunctionCall) goja.Value {
		filePath := call.Argument(0).String()
		fullPath, resErr := resolvePath(s, filePath)
		if resErr != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": resErr.Error()})
		}
		opts := map[string]interface{}{}
		if o := call.Argument(1).Export(); o != nil {
			if m, ok := o.(map[string]interface{}); ok {
				opts = m
			}
		}

		offset := intOpt(opts, "offset", 0)
		length := intOpt(opts, "length", 2048)
		encoding, _ := opts["encoding"].(string)

		f, err := os.Open(fullPath)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("open: %v", err)})
		}
		defer f.Close()

		if offset > 0 {
			if _, err := f.Seek(int64(offset), io.SeekStart); err != nil {
				return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("seek: %v", err)})
			}
		}

		buf := make([]byte, length)
		n, err := f.Read(buf)
		if n > 0 {
			buf = buf[:n]
		} else {
			buf = []byte{}
		}

		eof := err == io.EOF
		if err != nil && !eof {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("read: %v", err)})
		}

		var output string
		if encoding == "base64" {
			output = base64.StdEncoding.EncodeToString(buf)
		} else {
			output = string(buf)
		}

		return vm.ToValue(map[string]interface{}{
			"success":    true,
			"data":       output,
			"bytes_read": n,
			"eof":        eof,
		})
	})

	fileObj.Set("getSize", func(call goja.FunctionCall) goja.Value {
		filePath := call.Argument(0).String()
		fullPath, resErr := resolvePath(s, filePath)
		if resErr != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": resErr.Error()})
		}
		info, err := os.Stat(fullPath)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("stat: %v", err)})
		}
		return vm.ToValue(map[string]interface{}{"success": true, "size": info.Size()})
	})

	fileObj.Set("exists", func(call goja.FunctionCall) goja.Value {
		path := call.Argument(0).String()
		fullPath, err := resolvePath(s, path)
		if err != nil {
			return vm.ToValue(false)
		}
		_, err = os.Stat(fullPath)
		return vm.ToValue(err == nil)
	})

	fileObj.Set("delete", func(call goja.FunctionCall) goja.Value {
		path := call.Argument(0).String()
		fullPath, err := resolvePath(s, path)
		if err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		if err := os.Remove(fullPath); err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		return goja.Undefined()
	})

	fileObj.Set("list", func(call goja.FunctionCall) goja.Value {
		path := call.Argument(0).String()
		fullPath, err := resolvePath(s, path)
		if err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		entries, err := os.ReadDir(fullPath)
		if err != nil {
			panic(vm.NewTypeError(err.Error()))
		}
		names := make([]string, len(entries))
		for i, e := range entries {
			names[i] = e.Name()
		}
		return vm.ToValue(names)
	})
}

func intOpt(opts map[string]interface{}, key string, def int) int {
	if o, ok := opts[key].(int64); ok {
		return int(o)
	}
	if o, ok := opts[key].(float64); ok {
		return int(o)
	}
	return def
}
