package gobackend

import (
	"os"
	"path/filepath"

	core "github.com/zarz/bitly/go_backend/internal/core"
)

// =========================================================================
// HELPERS
// =========================================================================

func jsonError(err error) string {
	return `{"error":"` + err.Error() + `"}`
}

func jsonErrorString(msg string) string {
	return `{"error":"` + msg + `"}`
}

// extensionsDir resolves a writable directory for extension JS, portable across
// desktop and mobile (Android cwd is "/" and not writable).
func dirExtensiones() string {
	if d := os.Getenv("BITLY_EXT_DIR"); d != "" {
		return d
	}
	if d, err := os.UserConfigDir(); err == nil && d != "" {
		return filepath.Join(d, "bitly", "extensions")
	}
	return "extensions"
}

// binDataDir resolves a writable directory for downloaded tool binaries,
// portable across desktop and mobile (Android/iOS).
func dirDatosBin() string {
	if core.IsMobile() {
		if d := os.Getenv("BITLY_BIN_DIR"); d != "" {
			return d
		}
		// gomobile apps can read the app's files dir via env set by Flutter.
		if d, err := os.UserConfigDir(); err == nil && d != "" {
			return filepath.Join(d, "bitly", "bin")
		}
		return "bitly_bin"
	}
	if d := os.Getenv("BITLY_BIN_DIR"); d != "" {
		return d
	}
	if d, err := os.UserConfigDir(); err == nil && d != "" {
		return filepath.Join(d, "bitly", "bin")
	}
	return "./bin"
}
