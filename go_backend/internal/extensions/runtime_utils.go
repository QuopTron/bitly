package extensions

import (
	"crypto/hmac"
	"crypto/sha1"
	"math/rand"
	"time"

	"github.com/dop251/goja"
)

// registrarGlobalUtils construye (o reutiliza) el objeto `utils` con las
// utilidades compatibles SpotiFLAC-Mobile: user-agents aleatorios, versión de
// la app, cancelación de descargas, sleep y HMAC-SHA1 (para TOTP).
func registrarGlobalUtils(vm *goja.Runtime) {
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

	// appVersion() returns the app version (extensions build user agents / cache
	// keys from it). Kept stable so extension cache-busting works across builds.
	_ = utilsObj.Set("appVersion", func() string {
		return "1.0.0"
	})

	// isDownloadCancelled() reports whether the active download was cancelled.
	// The current runtime has no per-item cancel tracking, so it returns false —
	// extensions (Apple Music, Tidal) call it at the top of download() and would
	// throw a ReferenceError if it were absent, failing the whole download.
	_ = utilsObj.Set("isDownloadCancelled", func() bool { return false })

	// sleep(ms) blocks for the requested time, polling a (currently never-set)
	// cancel flag so future cancellation support is a drop-in. Returns false if
	// cancelled, true otherwise — Apple Music gates its download loop on this.
	_ = utilsObj.Set("sleep", func(call goja.FunctionCall) goja.Value {
		sleepMs := 0
		switch v := call.Argument(0).Export().(type) {
		case int64:
			sleepMs = int(v)
		case int32:
			sleepMs = int(v)
		case int:
			sleepMs = v
		case float64:
			sleepMs = int(v)
		default:
			sleepMs = 0
		}
		if sleepMs <= 0 {
			return vm.ToValue(true)
		}
		if sleepMs > 5*60*1000 {
			sleepMs = 5 * 60 * 1000
		}
		deadline := time.Now().Add(time.Duration(sleepMs) * time.Millisecond)
		for {
			remaining := time.Until(deadline)
			if remaining <= 0 {
				return vm.ToValue(true)
			}
			step := 100 * time.Millisecond
			if remaining < step {
				step = remaining
			}
			time.Sleep(step)
		}
	})

	// hmacSHA1(key, data) returns HMAC-SHA1 byte array for TOTP generation
	_ = utilsObj.Set("hmacSHA1", func(call goja.FunctionCall) goja.Value {
		keyArg := call.Argument(0).Export()
		dataArg := call.Argument(1).Export()

		keyBytes := aArregloBytes(keyArg)
		dataBytes := aArregloBytes(dataArg)

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
