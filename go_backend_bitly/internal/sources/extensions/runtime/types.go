package runtime

import (
	"net/http"
	"sync"
	"time"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

const DefaultJSTimeout = 30 * time.Second

type CallResult struct {
	Value   interface{}
	RawJSON string
}

type ExtensionRuntime struct {
	mu       sync.RWMutex
	runtimes map[string]*loadedExtensionRuntime
}

type loadedExtensionRuntime struct {
	extensionID string
	vm          *goja.Runtime
	sourceDir   string
	dataDir     string
	loadedAt    time.Time

	manifest       *manifest.ExtensionManifest
	httpClient     *http.Client
	downloadClient *http.Client
	cookieJar      http.CookieJar

	activeDownloadMu     sync.RWMutex
	activeDownloadItemID string

	activeRequestMu sync.RWMutex
	activeRequestID string

	storageMu      sync.RWMutex
	storageCache   map[string]interface{}
	storageLoaded  bool
	storageDirty   bool
	storageClosed  bool
	storageTimer   *time.Timer
	storageFlushDelay time.Duration
}

func (ler *loadedExtensionRuntime) setActiveDownloadItemID(itemID string) {
	ler.activeDownloadMu.Lock()
	defer ler.activeDownloadMu.Unlock()
	ler.activeDownloadItemID = itemID
}

func (ler *loadedExtensionRuntime) clearActiveDownloadItemID() {
	ler.activeDownloadMu.Lock()
	defer ler.activeDownloadMu.Unlock()
	ler.activeDownloadItemID = ""
}

func (ler *loadedExtensionRuntime) getActiveDownloadItemID() string {
	ler.activeDownloadMu.RLock()
	defer ler.activeDownloadMu.RUnlock()
	return ler.activeDownloadItemID
}

func (ler *loadedExtensionRuntime) setActiveRequestID(requestID string) {
	ler.activeRequestMu.Lock()
	defer ler.activeRequestMu.Unlock()
	ler.activeRequestID = requestID
}

func (ler *loadedExtensionRuntime) clearActiveRequestID() {
	ler.activeRequestMu.Lock()
	defer ler.activeRequestMu.Unlock()
	ler.activeRequestID = ""
}

func (ler *loadedExtensionRuntime) getActiveRequestID() string {
	ler.activeRequestMu.RLock()
	defer ler.activeRequestMu.RUnlock()
	return ler.activeRequestID
}

func NewExtensionRuntime() *ExtensionRuntime {
	return &ExtensionRuntime{
		runtimes: make(map[string]*loadedExtensionRuntime),
	}
}
