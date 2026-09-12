package extensions

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// debugLogMu protege debugLogPath/debugLogInited. Varias extensiones (y sus
// goroutines de bootstrap) inicializan y escriben este log a la vez; sin
// candado la ruta se escribía mientras otra goroutine la leía (data race
// sobre un string = puntero + longitud, puede leer una ruta corrupta).
var (
	debugLogMu     sync.RWMutex
	debugLogPath   string
	debugLogInited bool
)

func initDebugLogOnce(dataDir string) {
	debugLogMu.Lock()
	defer debugLogMu.Unlock()
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
	debugLogMu.RLock()
	ruta := debugLogPath
	debugLogMu.RUnlock()
	if ruta == "" {
		return
	}
	f, err := os.OpenFile(ruta, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
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
