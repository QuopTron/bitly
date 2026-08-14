package extensions

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
)

// DirExtensionManifest is the subset of manifest fields needed at load time.
type DirExtensionManifest struct {
	Name          string                `json:"name"`
	DisplayName   string                `json:"displayName"`
	Version       string                `json:"version"`
	SignedSession *SignedSessionConfig  `json:"signedSession,omitempty"`
}

// LoadDirExtensionsInto loads every extension stored as a subdirectory
// (dirPath/<extID>/index.js + manifest.json) into the given registry's
// runtime. It mirrors bundled_extensions.LoadAllToRegistry but reads from
// the filesystem, so the signed-session config from each manifest is
// attached to its sandbox (required for the Cloudflare verification flow).
//
// Returns the number of extensions successfully loaded.
func LoadDirExtensionsInto(reg *Registry, dirPath, dataDir string) int {
	entries, err := os.ReadDir(dirPath)
	if err != nil {
		return 0
	}

	cfg := DefaultConfig()
	cfg.EnableFS = true
	cfg.AllowedDirs = []string{"."}

	loaded := 0
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		extID := entry.Name()
		if strings.HasPrefix(extID, ".") {
			continue
		}
		// If the extension is already loaded (e.g. embedded by InitGlobalState
		// with the signed-session config attached), keep that sandbox. An
		// on-disk copy may be an older version missing the signedSession
		// manifest section, and replacing the sandbox would break the
		// Cloudflare verification flow. Still, point it at a writable data
		// dir so the signed-session record can persist and its install_id
		// stays stable across app restarts. Only override when the current
		// dir is empty or "." (embedded default) so the better data_dir from
		// initExtensionSystem is not clobbered by a later loadExtensionsFromDir.
		if sb := reg.Runtime().Sandbox(extID); sb != nil {
			if sb.DataDir == "" || sb.DataDir == "." {
				sb.DataDir = dataDir
			}
			continue
		}

		base := filepath.Join(dirPath, extID)
		manifestData, err := os.ReadFile(filepath.Join(base, "manifest.json"))
		if err != nil {
			continue
		}
		jsData, err := os.ReadFile(filepath.Join(base, "index.js"))
		if err != nil {
			continue
		}

		var manifest DirExtensionManifest
		if err := json.Unmarshal(manifestData, &manifest); err != nil {
			manifest.Name = extID
		}
		if manifest.Name == "" {
			manifest.Name = extID
		}

		if _, err := reg.Runtime().RunJS(string(jsData), extID, manifest.Name, cfg, dataDir); err != nil {
			continue
		}

		// Attach signed session config from manifest to the sandbox so the
		// Cloudflare verification flow (auth URL / grant exchange) works.
		if sb := reg.Runtime().Sandbox(extID); sb != nil && manifest.SignedSession != nil {
			sb.SignedSession = manifest.SignedSession
			sb.Session = &SignedSessionState{}
		}
		loaded++
	}
	return loaded
}
