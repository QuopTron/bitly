package handlers

import (
	"archive/zip"
	"fmt"
	"io"
	"path/filepath"
	"strings"
	"sync"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/api"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manager"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/runtime"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/share"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/store"
)

var (
	extManager *manager.Manager
	extRuntime *runtime.ExtensionRuntime
	extClient  *api.ActionClient
	extShare   *share.Service
	extStore   *store.Store
)

func ensureExtensionInit() {
	if extManager == nil {
		extManager = manager.NewManager()
	}
	if extRuntime == nil {
		extRuntime = runtime.NewExtensionRuntime()
	}
	if extClient == nil {
		extClient = api.NewActionClient(extRuntime)
	}
	if extShare == nil {
		extShare = share.NewService(extManager, extRuntime)
	}
	if extStore == nil {
		extStore = store.New(extManager, "")
	}
	// Always load embedded extensions so they're available
	// even before initExtensionSystem is called from Flutter.
	loadEmbeddedExtensions()
}

var (
	providerPriorityMu         sync.RWMutex
	providerPriority           []string
	metadataProviderPriorityMu sync.RWMutex
	metadataProviderPriority   []string
	fallbackExtensionIDsMu     sync.RWMutex
	fallbackExtensionIDs       []string
)

var (
	extSettingsMu sync.RWMutex
	extSettings   = map[string]map[string]interface{}{}
)

var (
	extAuthMu    sync.RWMutex
	extAuthState = map[string]*extensionAuthEntry{}
)

type extensionAuthEntry struct {
	PendingAuthURL  string
	AuthCode        string
	AccessToken     string
	RefreshToken    string
	IsAuthenticated bool
}

var (
	ffmpegCmdMu sync.RWMutex
	ffmpegCmds  = map[string]*ffmpegCmdEntry{}
)

type ffmpegCmdEntry struct {
	ExtensionID string
	Command     string
	Completed   bool
	Success     bool
	Output      string
	Error       string
}

var (
	cancelReqMu sync.RWMutex
	cancelReqs  = map[string]struct{}{}
)

func readManifestVersionFromZip(filePath string) (version, name string, err error) {
	reader, err := zip.OpenReader(filePath)
	if err != nil {
		return "", "", fmt.Errorf("cannot open file: %w", err)
	}
	defer reader.Close()

	for _, f := range reader.File {
		if strings.ToLower(filepath.Base(f.Name)) == "manifest.json" {
			rc, openErr := f.Open()
			if openErr != nil {
				return "", "", fmt.Errorf("cannot read manifest: %w", openErr)
			}
			data, readErr := io.ReadAll(rc)
			rc.Close()
			if readErr != nil {
				return "", "", fmt.Errorf("cannot read manifest: %w", readErr)
			}
			pManifest, parseErr := manifest.ParseManifest(data)
			if parseErr != nil {
				return "", "", fmt.Errorf("invalid manifest: %w", parseErr)
			}
			return pManifest.Version, pManifest.Name, nil
		}
	}
	return "", "", fmt.Errorf("manifest.json not found in archive")
}


