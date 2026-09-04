package extensions

import (
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

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
		fullPath, resErr := resolvePath(s, path)
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

		data, err := decodeBytesValue(call.Argument(1).Export(), encoding)
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

func runtimeOptString(opts map[string]interface{}, key, def string) string {
	if opts == nil {
		return def
	}
	raw, ok := opts[key]
	if !ok || raw == nil {
		return def
	}
	if s, ok := raw.(string); ok {
		if t := strings.TrimSpace(s); t != "" {
			return t
		}
	}
	return def
}

func runtimeOptBool(opts map[string]interface{}, key string, def bool) bool {
	if opts == nil {
		return def
	}
	raw, ok := opts[key]
	if !ok || raw == nil {
		return def
	}
	switch v := raw.(type) {
	case bool:
		return v
	case int:
		return v != 0
	case int64:
		return v != 0
	case float64:
		return v != 0
	case string:
		switch strings.ToLower(strings.TrimSpace(v)) {
		case "1", "true", "yes", "on":
			return true
		case "0", "false", "no", "off":
			return false
		}
	}
	return def
}

func runtimeOptInt64(opts map[string]interface{}, key string, def int64) int64 {
	if opts == nil {
		return def
	}
	raw, ok := opts[key]
	if !ok || raw == nil {
		return def
	}
	switch v := raw.(type) {
	case int:
		return int64(v)
	case int32:
		return int64(v)
	case int64:
		return v
	case float32:
		return int64(v)
	case float64:
		return int64(v)
	case string:
		v = strings.TrimSpace(v)
		if v == "" {
			return def
		}
		var parsed int64
		if _, err := fmt.Sscanf(v, "%d", &parsed); err == nil {
			return parsed
		}
	}
	return def
}

func runtimeOptHasKey(opts map[string]interface{}, key string) bool {
	if opts == nil {
		return false
	}
	_, exists := opts[key]
	return exists
}

// decodeBytesValue converts a goja payload (string / []byte / ArrayBuffer /
// []int) to bytes using the requested encoding (base64 default, hex, or utf8).
func decodeBytesValue(raw interface{}, encoding string) ([]byte, error) {
	switch v := raw.(type) {
	case string:
		return decodeBytesString(v, encoding)
	case []byte:
		out := make([]byte, len(v))
		copy(out, v)
		return out, nil
	case goja.ArrayBuffer:
		src := v.Bytes()
		out := make([]byte, len(src))
		copy(out, src)
		return out, nil
	case []interface{}:
		out := make([]byte, len(v))
		for i, item := range v {
			switch n := item.(type) {
			case int:
				out[i] = byte(n)
			case int64:
				out[i] = byte(n)
			case float64:
				out[i] = byte(int(n))
			default:
				return nil, fmt.Errorf("unsupported byte array item at index %d", i)
			}
		}
		return out, nil
	default:
		return nil, fmt.Errorf("unsupported byte payload type")
	}
}

func decodeBytesString(input, encoding string) ([]byte, error) {
	switch strings.ToLower(strings.TrimSpace(encoding)) {
	case "", "utf8", "utf-8", "text":
		return []byte(input), nil
	case "base64":
		decoded, err := base64.StdEncoding.DecodeString(strings.TrimSpace(input))
		if err != nil {
			return nil, fmt.Errorf("invalid base64 data: %w", err)
		}
		return decoded, nil
	case "hex":
		decoded, err := hex.DecodeString(strings.TrimSpace(input))
		if err != nil {
			return nil, fmt.Errorf("invalid hex data: %w", err)
		}
		return decoded, nil
	default:
		return nil, fmt.Errorf("unsupported byte encoding: %s", encoding)
	}
}
