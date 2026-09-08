package extensions

import (
	"strings"
	"sync"
)

var (
	signedSessionBaseDirMu     sync.RWMutex
	signedSessionBaseDir       string
	signedSessionCallbackURLMu sync.RWMutex
	signedSessionCallbackURL   string
)

// SetSignedSessionCallbackURL sobreescribe la URL de callback usada al
// construir URLs de challenge de Cloudflare (en vez del callbackUrl del
// manifest). El desktop la apunta a un servidor HTTP loopback para que el
// grant vuelva a la app sin esquema URI propio; vacio en movil para usar el
// deep link spotiflac:// del manifest.
func SetSignedSessionCallbackURL(url string) {
	signedSessionCallbackURLMu.Lock()
	signedSessionCallbackURL = strings.TrimSpace(url)
	signedSessionCallbackURLMu.Unlock()
}

// SetSignedSessionDataDir re-apunta la persistencia de sesiones firmadas a un
// directorio escribible. Sin esto, los sandboxes embebidos (dataDir "." en
// Android) no pueden persistir la sesion verificada por Cloudflare, asi que
// cada arranque regenera un install_id nuevo y pide verificacion humana de
// nuevo. Llamarlo con el dir real escribible de la app (p. ej. desde el
// setDownloadDirectory de Flutter) antes de cualquier streaming.
func SetSignedSessionDataDir(dir string) {
	trimmed := strings.TrimSpace(dir)
	signedSessionBaseDirMu.Lock()
	signedSessionBaseDir = trimmed
	signedSessionBaseDirMu.Unlock()
}
