package extensions

import (
	"fmt"
	"os"
	"path/filepath"
	"time"
)

var debugLogPath string
var debugLogInited bool

func initDebugLogOnce(dataDir string) {
	if debugLogInited {
		return
	}
	debugLogInited = true
	// Write to sdcard so we can read it without root
	for _, p := range []string{
		"/sdcard/signed_session_debug.log",
		filepath.Join(dataDir, "signed_session_debug.log"),
	} {
		f, err := os.OpenFile(p, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0666)
		if err == nil {
			f.Close()
			debugLogPath = p
			return
		}
	}
	// Fallback to dataDir
	debugLogPath = filepath.Join(dataDir, "signed_session_debug.log")
}

func debugLog(msg string) {
	if debugLogPath == "" {
		return
	}
	f, err := os.OpenFile(debugLogPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "[%s] %s\n", time.Now().Format("15:04:05.000"), msg)
}

// =========================================================================
// Sandbox bridge — used by exports.go so Flutter can drive the Cloudflare
// signed-session flow (auth URL, complete grant, status) directly against
// el sandbox runtime where sesiones actually live.// =========================================================================

// SignedSessionAuthURL triggers bootstrap for a sandbox and returns the
// Cloudflare challenge URL. If the session was provisioned silently, it
// Devuelve un vacío URL (nothing un verificar).
