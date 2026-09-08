package extensions

import (
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/dop251/goja"
)

// registerFileWriteOps adds file.writeBytes to the JS runtime. Extensions use
// it to assemble segmented / decrypted downloads (e.g. Deezer and Tidal write
// base64 audio chunks) so it must accept base64, hex and raw encodings plus
// offset/append/truncate semantics like the SpotiFLAC reference runtime.
func registerFileWriteOps(s *Sandbox, fileObj *goja.Object) {
	vm := s.VM

	fileObj.Set("writeBytes", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 2 {
			return vm.ToValue(map[string]interface{}{"success": false, "error": "path and data are required"})
		}

		path := call.Argument(0).String()
		fullPath, resErr := resolverRuta(s, path)
		if resErr != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": resErr.Error()})
		}

		opts := map[string]interface{}{}
		if o := call.Argument(2).Export(); o != nil {
			if m, ok := o.(map[string]interface{}); ok {
				opts = m
			}
		}

		appendMode := runtimeOptBool(opts, "append", false)
		truncate := runtimeOptBool(opts, "truncate", false)
		hasOffset := runtimeOptHasKey(opts, "offset")
		offset := runtimeOptInt64(opts, "offset", 0)
		encoding := runtimeOptString(opts, "encoding", "base64")

		if appendMode && hasOffset {
			return vm.ToValue(map[string]interface{}{"success": false, "error": "append and offset cannot be used together"})
		}
		if offset < 0 {
			return vm.ToValue(map[string]interface{}{"success": false, "error": "offset must be >= 0"})
		}

		data, err := decodificarBytesValor(call.Argument(1).Export(), encoding)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
		}

		dir := filepath.Dir(fullPath)
		if err := os.MkdirAll(dir, 0755); err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to create directory: %v", err)})
		}

		flags := os.O_CREATE | os.O_WRONLY
		if appendMode {
			flags |= os.O_APPEND
		}
		if truncate {
			flags |= os.O_TRUNC
		}

		f, err := os.OpenFile(fullPath, flags, 0644)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
		}
		defer f.Close()

		if hasOffset && !appendMode {
			if _, err := f.Seek(offset, io.SeekStart); err != nil {
				return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to seek file: %v", err)})
			}
		}

		written, err := f.Write(data)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
		}

		info, statErr := f.Stat()
		size := int64(0)
		if statErr == nil {
			size = info.Size()
		}

		return vm.ToValue(map[string]interface{}{
			"success":       true,
			"path":          fullPath,
			"bytes_written": written,
			"size":          size,
		})
	})
}

// Las helpers runtimeOptString/runtimeOptBool/runtimeOptInt64/runtimeOptHasKey
// viven en file_write_opts.go y los decoders en file_write_decode.go.
