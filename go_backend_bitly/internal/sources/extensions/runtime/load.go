package runtime

import (
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

func (r *ExtensionRuntime) LoadExtension(extensionID, filePath string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	jsSource, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read extension %q source: %w", extensionID, err)
	}

	vm := goja.New()
	registerPolyfills(vm)
	registerConsole(vm, extensionID)

	_, err = vm.RunString(string(jsSource))
	if err != nil {
		return fmt.Errorf("failed to execute extension %q: %w", extensionID, err)
	}

	extObj := vm.Get("extension")
	if extObj == nil || goja.IsUndefined(extObj) {
		return fmt.Errorf("extension %q does not expose an 'extension' object", extensionID)
	}

	r.runtimes[extensionID] = &loadedExtensionRuntime{
		extensionID: extensionID,
		vm:          vm,
		loadedAt:    time.Now(),
	}

	return nil
}

func (r *ExtensionRuntime) LoadExtensionWithDirs(extensionID, filePath, sourceDir, dataDir string, mf *manifest.ExtensionManifest) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	jsSource, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read extension %q source: %w", extensionID, err)
	}

	vm := goja.New()
	registerPolyfills(vm)
	registerConsole(vm, extensionID)

	ler := &loadedExtensionRuntime{
		extensionID:       extensionID,
		vm:                vm,
		sourceDir:         sourceDir,
		dataDir:           dataDir,
		loadedAt:          time.Now(),
		manifest:          mf,
		storageFlushDelay: 400 * time.Millisecond,
	}

	if mf != nil {
		jar := newSimpleCookieJar()
		ler.cookieJar = jar
		ler.httpClient = newExtensionHTTPClient(ler, jar, extensionHTTPTimeout(ler, 30*time.Second))
		ler.downloadClient = newExtensionHTTPClient(ler, jar, 5*time.Minute)
	}

	_, err = vm.RunString(string(jsSource))
	if err != nil {
		return fmt.Errorf("failed to execute extension %q: %w", extensionID, err)
	}

	extObj := vm.Get("extension")
	if extObj == nil || goja.IsUndefined(extObj) {
		return fmt.Errorf("extension %q does not expose an 'extension' object", extensionID)
	}

	ler.registerExtensionAPIs()

	r.runtimes[extensionID] = ler
	return nil
}

func extensionHTTPTimeout(ler *loadedExtensionRuntime, fallback time.Duration) time.Duration {
	if ler == nil || ler.manifest == nil || ler.manifest.Capabilities == nil {
		return fallback
	}
	raw, ok := ler.manifest.Capabilities["networkTimeoutSeconds"]
	if !ok {
		return fallback
	}
	seconds := parseExtensionTimeoutSeconds(raw)
	if seconds <= 0 {
		return fallback
	}
	if seconds < 5 {
		seconds = 5
	}
	if seconds > 300 {
		seconds = 300
	}
	return time.Duration(seconds) * time.Second
}

func parseExtensionTimeoutSeconds(raw interface{}) int {
	switch v := raw.(type) {
	case int:
		return v
	case int32:
		return int(v)
	case int64:
		return int(v)
	case float32:
		return int(v)
	case float64:
		return int(v)
	case string:
		parsed := 0
		fmt.Sscanf(v, "%d", &parsed)
		return parsed
	default:
		return 0
	}
}

func newExtensionHTTPClient(ler *loadedExtensionRuntime, jar http.CookieJar, timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout: timeout,
		Jar:     jar,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if err := validateDomain(req.URL.String(), ler.manifest); err != nil {
				return err
			}
			if len(via) >= 10 {
				return http.ErrUseLastResponse
			}
			return nil
		},
	}
}
