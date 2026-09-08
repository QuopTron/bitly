package extensions

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func (s *SignedSessionState) persistRecord(cfg SignedSessionConfig) {
	if s.Record == nil {
		return
	}
	path, err := rutaArchivoSesionFirmada(s.dataDir, cfg)
	if err != nil {
		return
	}
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return
	}
	data, _ := json.MarshalIndent(s.Record, "", "  ")
	_ = os.WriteFile(path, data, 0600)
}

func rutaArchivoSesionFirmada(dataDir string, cfg SignedSessionConfig) (string, error) {
	// Prefer the explicit writable base dir (set by Flutter's
	// setDownloadDirectory). Embedded sandboxes run with dataDir "." on
	// Android (cwd "/", read-only), so without this override the verified
	// Cloudflare session can never be persisted and the captcha is requested
	// again on every launch.
	base := dataDir
	signedSessionBaseDirMu.RLock()
	if override := signedSessionBaseDir; override != "" {
		base = override
	}
	signedSessionBaseDirMu.RUnlock()

	namespace := sanitizarNamespaceSesionFirmada(cfg.Namespace)
	if namespace == "" {
		return "", fmt.Errorf("signed session namespace is empty")
	}
	scope := strings.Join([]string{
		namespace,
		strings.ToLower(strings.TrimSpace(cfg.BaseURL)),
		strings.ToLower(strings.TrimSpace(cfg.AppVersion)),
		strings.ToLower(strings.TrimSpace(cfg.Platform)),
	}, "\n")
	sum := sha256.Sum256([]byte(scope))
	dir := filepath.Join(base, "signed_sessions")
	return filepath.Join(dir, namespace+"-"+hex.EncodeToString(sum[:])[:16]+".json"), nil
}
