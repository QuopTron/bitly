package extensions

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend/internal/audio"
)

// toByteArray converts a goja value (expected []interface{}) to a byte slice.
func aArregloBytes(v interface{}) []byte {
	if v == nil {
		return nil
	}
	if arr, ok := v.([]interface{}); ok {
		result := make([]byte, len(arr))
		for i, val := range arr {
			switch n := val.(type) {
			case int64:
				result[i] = byte(n)
			case float64:
				result[i] = byte(n)
			case int:
				result[i] = byte(n)
			}
		}
		return result
	}
	return nil
}

// checkISRCExistsInDir scans audio files in [dir] and returns the path of the
// first file whose embedded ISRC metadata equals [isrc] (case-insensitive),
// plus whether one was found. Used by extensions to skip duplicate downloads.
func verificarISRCEnDir(dir, isrc string) (string, bool) {
	isrc = strings.ToUpper(strings.TrimSpace(isrc))
	if isrc == "" {
		return "", false
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return "", false
	}
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		path := filepath.Join(dir, e.Name())
		meta, err := audio.ReadFileMetadata(path)
		if err != nil || meta.ISRC == "" {
			continue
		}
		if strings.ToUpper(strings.TrimSpace(meta.ISRC)) == isrc {
			return path, true
		}
	}
	return "", false
}

// sandboxURLConstructor returns a goja-compatible URL constructor.
func constructorURLSandbox(vm *goja.Runtime) func(goja.ConstructorCall) *goja.Object {
	return func(call goja.ConstructorCall) *goja.Object {
		urlStr := call.Argument(0).String()
		baseStr := ""
		if !goja.IsUndefined(call.Argument(1)) && !goja.IsNull(call.Argument(1)) {
			baseStr = call.Argument(1).String()
		}

		fullURL := urlStr
		if baseStr != "" {
			fullURL = baseStr + urlStr
		}

		u, err := urlParse(fullURL)
		if err != nil {
			panic(vm.NewTypeError("Failed to construct URL: " + err.Error()))
		}

		obj := vm.NewObject()
		_ = obj.Set("href", u.href)
		_ = obj.Set("protocol", u.protocol)
		_ = obj.Set("hostname", u.hostname)
		_ = obj.Set("host", u.host)
		_ = obj.Set("port", u.port)
		_ = obj.Set("pathname", u.pathname)
		_ = obj.Set("search", u.search)
		_ = obj.Set("hash", u.hash)
		_ = obj.Set("origin", u.origin)

		spObj := vm.NewObject()
		_ = spObj.Set("get", func(call goja.FunctionCall) goja.Value {
			key := call.Argument(0).String()
			if val, ok := u.params[key]; ok {
				return vm.ToValue(val)
			}
			return goja.Undefined()
		})
		_ = obj.Set("searchParams", spObj)
		_ = obj.Set("toString", func() string { return u.href })

		return obj
	}
}
