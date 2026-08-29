package extensions

import (
	"crypto/hmac"
	"crypto/sha1"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend/internal/audio"
	"github.com/zarz/bitly/go_backend/internal/lyrics"
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

	// getAudioQuality(path) reads audio quality metadata from a downloaded file.
	// Extensions (Tidal, Qobuz) use it to verify the acquired quality before
	// finalizing a download.
	_ = gobackendObj.Set("getAudioQuality", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 1 {
			return vm.ToValue(map[string]interface{}{"error": "file path is required"})
		}
		path := call.Argument(0).String()
		meta, err := audio.ReadFileMetadata(path)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"error": err.Error()})
		}
		return vm.ToValue(map[string]interface{}{
			"bitDepth":   meta.BitDepth,
			"sampleRate": meta.SampleRate,
			"duration":   meta.DurationMs,
			"codec":      meta.Format,
		})
	})

	// getLyricsLRC(spotifyID, trackName, artistName, filePath, durationMs)
	// returns synced (or plain) lyrics for the track, embedding the instrumental
	// sentinel when there are none — the same contract the player consumes.
	_ = gobackendObj.Set("getLyricsLRC", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 3 {
			return vm.ToValue(map[string]interface{}{"error": "spotifyID, trackName and artistName are required"})
		}
		trackName := strings.TrimSpace(call.Arguments[1].String())
		artistName := strings.TrimSpace(call.Arguments[2].String())
		var durationMs int
		if len(call.Arguments) > 4 && !goja.IsUndefined(call.Arguments[4]) && !goja.IsNull(call.Arguments[4]) {
			durationMs = int(call.Arguments[4].ToInteger())
		}
		lyr, err := lyrics.NewClient().GetLyrics(trackName, artistName, durationMs)
		if err != nil || lyr == nil {
			return vm.ToValue(map[string]interface{}{"lyrics": "[instrumental:true]"})
		}
		text := lyr.SyncedLyrics
		if text == "" {
			text = lyr.PlainLyrics
		}
		if text == "" {
			text = "[instrumental:true]"
		}
		return vm.ToValue(map[string]interface{}{"lyrics": text})
	})

	// checkISRCExists(outputDir, isrc) returns the path of an already-downloaded
	// file in [outputDir] whose metadata ISRC matches, so extensions can skip
	// re-downloading duplicates.
	_ = gobackendObj.Set("checkISRCExists", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 2 {
			return vm.ToValue(map[string]interface{}{"error": "outputDir and isrc are required"})
		}
		outputDir := strings.TrimSpace(call.Arguments[0].String())
		isrc := strings.TrimSpace(call.Arguments[1].String())
		if outputDir == "" || isrc == "" {
			return vm.ToValue(map[string]interface{}{"error": "outputDir and isrc are required"})
		}
		filePath, exists := checkISRCExistsInDir(outputDir, isrc)
		return vm.ToValue(map[string]interface{}{"exists": exists, "filePath": filePath})
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

// checkISRCExistsInDir scans audio files in [dir] and returns the path of the
// first file whose embedded ISRC metadata equals [isrc] (case-insensitive),
// plus whether one was found. Used by extensions to skip duplicate downloads.
func checkISRCExistsInDir(dir, isrc string) (string, bool) {
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
