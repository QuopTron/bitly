package runtime

import (
	"fmt"
	"net/url"
	"strings"

	"github.com/dop251/goja"
)

func (ler *loadedExtensionRuntime) registerURLClass() {
	ler.vm.Set("URL", func(call goja.ConstructorCall) *goja.Object {
		urlObj := call.This
		if len(call.Arguments) < 1 { urlObj.Set("href", ""); return nil }
		urlStr := call.Arguments[0].String()
		if len(call.Arguments) > 1 && !goja.IsUndefined(call.Arguments[1]) {
			baseStr := call.Arguments[1].String()
			if baseURL, err := url.Parse(baseStr); err == nil {
				if relURL, err := url.Parse(urlStr); err == nil {
					urlStr = baseURL.ResolveReference(relURL).String()
				}
			}
		}
		parsed, err := url.Parse(urlStr)
		if err != nil { urlObj.Set("href", urlStr); return nil }
		urlObj.Set("href", parsed.String())
		urlObj.Set("protocol", parsed.Scheme+":")
		urlObj.Set("host", parsed.Host)
		urlObj.Set("hostname", parsed.Hostname())
		urlObj.Set("port", parsed.Port())
		urlObj.Set("pathname", parsed.Path)
		urlObj.Set("search", "")
		if parsed.RawQuery != "" { urlObj.Set("search", "?"+parsed.RawQuery) }
		urlObj.Set("hash", "")
		if parsed.Fragment != "" { urlObj.Set("hash", "#"+parsed.Fragment) }
		urlObj.Set("origin", parsed.Scheme+"://"+parsed.Host)
		password, _ := parsed.User.Password()
		urlObj.Set("username", parsed.User.Username())
		urlObj.Set("password", password)
		searchParams := ler.vm.NewObject()
		q := parsed.Query()
		searchParams.Set("get", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) < 1 { return goja.Null() }
			if val := q.Get(call.Arguments[0].String()); val != "" { return ler.vm.ToValue(val) }
			return goja.Null()
		})
		searchParams.Set("getAll", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) < 1 { return ler.vm.ToValue([]string{}) }
			return ler.vm.ToValue(q[call.Arguments[0].String()])
		})
		searchParams.Set("has", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) < 1 { return ler.vm.ToValue(false) }
			return ler.vm.ToValue(q.Has(call.Arguments[0].String()))
		})
		searchParams.Set("toString", func(call goja.FunctionCall) goja.Value {
			return ler.vm.ToValue(q.Encode())
		})
		urlObj.Set("searchParams", searchParams)
		urlObj.Set("toString", func(call goja.FunctionCall) goja.Value { return ler.vm.ToValue(parsed.String()) })
		urlObj.Set("toJSON", func(call goja.FunctionCall) goja.Value { return ler.vm.ToValue(parsed.String()) })
		return nil
	})

	ler.vm.Set("URLSearchParams", func(call goja.ConstructorCall) *goja.Object {
		paramsObj := call.This
		values := url.Values{}
		if len(call.Arguments) > 0 && !goja.IsUndefined(call.Arguments[0]) {
			switch v := call.Arguments[0].Export().(type) {
			case string:
				parsed, _ := url.ParseQuery(strings.TrimPrefix(v, "?"))
				values = parsed
			case map[string]interface{}:
				for k, val := range v { values.Set(k, fmt.Sprintf("%v", val)) }
			}
		}
		paramsObj.Set("append", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) >= 2 { values.Add(call.Arguments[0].String(), call.Arguments[1].String()) }
			return goja.Undefined()
		})
		paramsObj.Set("delete", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) >= 1 { values.Del(call.Arguments[0].String()) }
			return goja.Undefined()
		})
		paramsObj.Set("get", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) < 1 { return goja.Null() }
			if val := values.Get(call.Arguments[0].String()); val != "" { return ler.vm.ToValue(val) }
			return goja.Null()
		})
		paramsObj.Set("getAll", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) < 1 { return ler.vm.ToValue([]string{}) }
			return ler.vm.ToValue(values[call.Arguments[0].String()])
		})
		paramsObj.Set("has", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) < 1 { return ler.vm.ToValue(false) }
			return ler.vm.ToValue(values.Has(call.Arguments[0].String()))
		})
		paramsObj.Set("set", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) >= 2 { values.Set(call.Arguments[0].String(), call.Arguments[1].String()) }
			return goja.Undefined()
		})
		paramsObj.Set("toString", func(call goja.FunctionCall) goja.Value {
			return ler.vm.ToValue(values.Encode())
		})
		return nil
	})
}

func (ler *loadedExtensionRuntime) registerTextEncoder() {
	ler.vm.Set("TextEncoder", func(call goja.ConstructorCall) *goja.Object {
		enc := call.This
		enc.Set("encoding", "utf-8")
		enc.Set("encode", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) < 1 { return ler.vm.ToValue([]interface{}{}) }
			bytes := []byte(call.Arguments[0].String())
			result := make([]interface{}, len(bytes))
			for i, b := range bytes { result[i] = int(b) }
			return ler.vm.ToValue(result)
		})
		enc.Set("encodeInto", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) < 2 { return ler.vm.ToValue(map[string]interface{}{"read": 0, "written": 0}) }
			input := call.Arguments[0].String()
			return ler.vm.ToValue(map[string]interface{}{"read": len(input), "written": len([]byte(input))})
		})
		return nil
	})

	ler.vm.Set("TextDecoder", func(call goja.ConstructorCall) *goja.Object {
		dec := call.This
		encoding := "utf-8"
		if len(call.Arguments) > 0 && !goja.IsUndefined(call.Arguments[0]) { encoding = call.Arguments[0].String() }
		dec.Set("encoding", encoding)
		dec.Set("fatal", false)
		dec.Set("ignoreBOM", false)
		dec.Set("decode", func(call goja.FunctionCall) goja.Value {
			if len(call.Arguments) < 1 { return ler.vm.ToValue("") }
			input := call.Arguments[0].Export()
			var bytes []byte
			switch v := input.(type) {
			case []byte: bytes = v
			case []interface{}:
				bytes = make([]byte, len(v))
				for i, val := range v {
					switch n := val.(type) {
					case int64: bytes[i] = byte(n)
					case float64: bytes[i] = byte(n)
					}
				}
			case string: return ler.vm.ToValue(v)
			default: return ler.vm.ToValue("")
			}
			return ler.vm.ToValue(string(bytes))
		})
		return nil
	})
}
