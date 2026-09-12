package extensions

import (
	"path/filepath"
	"sync"
	"testing"
)

// TestStressLogDepuracionSinCarreras reproduce el uso real: varias extensiones
// (y sus goroutines de bootstrap) inicializan y escriben el log de sesiones
// firmadas a la vez. Sin candado, la ruta se escribía mientras otra goroutine
// la leía — un race sobre un string (puntero + longitud).
func TestStressLogDepuracionSinCarreras(t *testing.T) {
	dir := t.TempDir()

	const vueltas = 200
	arranque := make(chan struct{})
	var wg sync.WaitGroup

	for w := 0; w < 3; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-arranque
			for i := 0; i < vueltas; i++ {
				initDebugLogOnce(dir)
			}
		}()
	}

	for r := 0; r < 3; r++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-arranque
			for i := 0; i < vueltas; i++ {
				debugLog("prueba de concurrencia")
			}
		}()
	}

	close(arranque)
	wg.Wait()

	debugLogMu.RLock()
	ruta := debugLogPath
	debugLogMu.RUnlock()
	if ruta == "" {
		t.Fatal("esperaba una ruta de log inicializada")
	}
	if filepath.Base(ruta) != "signed_session_debug.log" {
		t.Fatalf("ruta inesperada: %s", ruta)
	}
}

// TestInitDebugLogEsIdempotente verifica que solo la primera llamada fija la
// ruta (el segundo dataDir no la debe pisar).
func TestInitDebugLogEsIdempotente(t *testing.T) {
	primero := t.TempDir()
	segundo := t.TempDir()

	debugLogMu.Lock()
	debugLogPath = ""
	debugLogInited = false
	debugLogMu.Unlock()

	initDebugLogOnce(primero)
	debugLogMu.RLock()
	ruta1 := debugLogPath
	debugLogMu.RUnlock()

	initDebugLogOnce(segundo)
	debugLogMu.RLock()
	ruta2 := debugLogPath
	debugLogMu.RUnlock()

	if ruta1 != ruta2 {
		t.Fatalf("la segunda inicialización pisó la ruta: %q → %q", ruta1, ruta2)
	}
}
