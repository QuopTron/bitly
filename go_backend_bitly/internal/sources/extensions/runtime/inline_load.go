package runtime

import (
	"fmt"
	"time"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

// InlineLoad loads an extension from a JS byte slice without touching the
// filesystem. This is used for embedded/bundled extensions where the JS
// source comes from go:embed rather than disk.
func (r *ExtensionRuntime) InlineLoad(extensionID string, jsSource []byte, sourceDir, dataDir string, mf *manifest.ExtensionManifest) error {
	r.mu.Lock()
	defer r.mu.Unlock()

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

	// Register all APIs BEFORE running the extension script
	ler.registerExtensionAPIs()
	ler.registerRegisterExtension()

	_, err := vm.RunString(string(jsSource))
	if err != nil {
		return fmt.Errorf("failed to execute extension %q: %w", extensionID, err)
	}

	extObj := vm.Get("extension")
	if extObj == nil || goja.IsUndefined(extObj) {
		return fmt.Errorf("extension %q does not expose an 'extension' object", extensionID)
	}

	r.runtimes[extensionID] = ler
	return nil
}
