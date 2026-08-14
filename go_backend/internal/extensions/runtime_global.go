package extensions

import (
	"crypto/hmac"
	"crypto/sha1"
	"math/rand"
	"time"

	"github.com/dop251/goja"
)

func registerGlobal(sandbox *Sandbox) {
	vm := sandbox.VM

	// registerExtension(callbacks) - stores extension callbacks as global functions
	_ = vm.Set("registerExtension", func(call goja.FunctionCall) goja.Value {
		obj := call.Argument(0).Export()
		if obj == nil {
			return goja.Undefined()
		}
		if extObj, ok := obj.(map[string]interface{}); ok {
			for name, fn := range extObj {
				if _, isFn := goja.AssertFunction(vm.ToValue(fn)); isFn {
					_ = vm.Set(name, fn)
				}
			}
		}
		return goja.Undefined()
	})

	// URL constructor - minimal polyfill for parsing URLs
	_ = vm.Set("URL", sandboxURLConstructor(vm))

	// Minimal Intl polyfill for Amazon extension
	intlObj := vm.NewObject()
	dtfObj := vm.NewObject()
	_ = dtfObj.Set("resolvedOptions", func() map[string]interface{} {
		return map[string]interface{}{
			"timeZone": "UTC",
		}
	})
	_ = intlObj.Set("DateTimeFormat", func(call goja.FunctionCall) goja.Value {
		return vm.ToValue(dtfObj)
	})
	_ = vm.Set("Intl", intlObj)

	// gobackend global - provides SpotiFLAC-Mobile compatible API for extensions
	gobackendObj := vm.NewObject()

	// getLocalTime() returns current local time info
	// SpotiFLAC-Mobile extensions expect: hour, minute, second, timezone, offsetMinutes
	_ = gobackendObj.Set("getLocalTime", func() map[string]interface{} {
		now := time.Now()
		_, offsetSec := now.Zone()
		return map[string]interface{}{
			"hour":          now.Hour(),
			"minute":        now.Minute(),
			"second":        now.Second(),
			"timezone":      now.Location().String(),
			"offsetMinutes": offsetSec / 60,
		}
	})

	// getGreeting() returns time-based greeting
	_ = gobackendObj.Set("getGreeting", func() string {
		h := time.Now().Hour()
		switch {
		case h < 12:
			return "Buenos días"
		case h < 18:
			return "Buenas tardes"
		default:
			return "Buenas noches"
		}
	})

	vm.Set("gobackend", gobackendObj)

	// utils global - provides SpotiFLAC-Mobile compatible utility functions
	// Reuse the existing utils object if present (registerCryptoUtils added
	// sha256/md5/base64/etc. earlier) instead of clobbering it with a fresh one,
	// which previously dropped utils.sha256 and broke Deezer streaming.
	utilsObj := vm.NewObject()
	if existing := vm.Get("utils"); existing != nil && !goja.IsUndefined(existing) {
		if obj, ok := existing.(*goja.Object); ok {
			utilsObj = obj
		}
	}

	// randomUserAgent() returns a random user agent string
	_ = utilsObj.Set("randomUserAgent", func() string {
		uas := []string{
			"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
			"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
			"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
			"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
			"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
			"Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
			"Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36",
		}
		return uas[rand.Intn(len(uas))]
	})

	// appUserAgent() returns the app user agent
	_ = utilsObj.Set("appUserAgent", func() string {
		return "Bitly/1.0"
	})

	// hmacSHA1(key, data) returns HMAC-SHA1 byte array for TOTP generation
	_ = utilsObj.Set("hmacSHA1", func(call goja.FunctionCall) goja.Value {
		keyArg := call.Argument(0).Export()
		dataArg := call.Argument(1).Export()

		keyBytes := toByteArray(keyArg)
		dataBytes := toByteArray(dataArg)

		mac := hmac.New(sha1.New, keyBytes)
		mac.Write(dataBytes)
		hash := mac.Sum(nil)

		// Return as array of int (Goja handles []byte as array of ints)
		result := make([]int, len(hash))
		for i, b := range hash {
			result[i] = int(b)
		}
		return vm.ToValue(result)
	})

	vm.Set("utils", utilsObj)
}

// toByteArray converts a goja value (expected []interface{}) to a byte slice.
func toByteArray(v interface{}) []byte {
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

// sandboxURLConstructor returns a goja-compatible URL constructor.
func sandboxURLConstructor(vm *goja.Runtime) func(goja.ConstructorCall) *goja.Object {
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
