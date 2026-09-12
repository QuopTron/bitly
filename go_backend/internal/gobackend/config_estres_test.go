package gobackend

import (
	"sync"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// =========================================================================
// ESTRÉS DE CONFIGURACIÓN EN CALIENTE
// =========================================================================
//
// Estos tests reproducen el patrón REAL de la app: Flutter guarda ajustes
// (carpeta de descargas, modo, tope de caché, callback, credenciales) desde
// el hilo del puente EN CUALQUIER MOMENTO, mientras una descarga en curso, un
// stream sirviéndose o el barrido del caché leen la misma configuración desde
// otras goroutines.
//
// Sin el candado de config_candado.go, `go test -race` marca data race en los
// escalares y —peor— el runtime puede abortar con "concurrent map read and map
// write" en los mapas de ajustes/sesiones. Por eso el valor está en correrlo
// con -race.

func TestStressConfigEnCaliente(t *testing.T) {
	prevDir := getDownloadDir()
	prevMode := getUserMode()
	prevMB := getStreamCacheMaxMB()
	prevCB := getCallbackID()
	defer func() {
		setDownloadDir(prevDir)
		setUserMode(prevMode)
		setStreamCacheMaxMB(prevMB)
		setCallbackID(prevCB)
	}()

	dir := t.TempDir()
	setDownloadDir(dir)

	const vueltas = 400
	modos := []string{"free", "premium", "lifetime", ""}

	arranque := make(chan struct{})
	var wg sync.WaitGroup

	// Escritores: exactamente lo que Flutter manda desde Ajustes.
	for w := 0; w < 2; w++ {
		wg.Add(1)
		go func(w int) {
			defer wg.Done()
			<-arranque
			for i := 0; i < vueltas; i++ {
				setDownloadDir(dir)
				setUserMode(modos[i%len(modos)])
				setStreamCacheMaxMB(i)
				setCallbackID("cb")
				setAjustesExtension("deezer", map[string]string{"arl": "x"})
				setSessionConfigGuardado("deezer", &extensions.SignedSessionConfig{})
			}
		}(w)
	}

	// Lectores: los caminos que consumen la configuración mientras se descarga
	// o se sirve un stream.
	for r := 0; r < 4; r++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-arranque
			for i := 0; i < vueltas; i++ {
				_ = getDownloadDir()
				_ = getUserMode()
				_ = getStreamCacheMaxMB()
				_ = getCallbackID()
				_ = userLevelLabel()
				_ = limiteMBPortadas()
				_ = rutaDirPortadas()
				_ = streamCacheDirPath()
				_ = getAjustesExtension("deezer")
				_ = snapshotAjustesExtensiones()
				_ = getSessionConfigGuardado("deezer")
			}
		}()
	}

	close(arranque)
	wg.Wait()
}

// TestStressPuenteAjustesConcurrente ejerce las funciones EXPORTADAS del
// puente (las que Flutter llama de verdad) contra lectores concurrentes, para
// que la carrera se detecte en la capa que usa la app y no solo en el accesor.
func TestStressPuenteAjustesConcurrente(t *testing.T) {
	// SetDownloadDirectory toca DOS globales más (el dir de salida del
	// orquestador y el de sesiones firmadas). Se restauran para no filtrar
	// estado a los demás tests del paquete.
	prevDir := getDownloadDir()
	prevMode := getUserMode()
	prevMB := getStreamCacheMaxMB()
	prevOut := download.GlobalOutputDir()
	defer func() {
		setDownloadDir(prevDir)
		setUserMode(prevMode)
		setStreamCacheMaxMB(prevMB)
		download.SetGlobalOutputDir(prevOut)
		extensions.SetSignedSessionDataDir("")
	}()

	dir := t.TempDir()
	payloadDir := `{"path":"` + escapeRutaJSON(dir) + `"}`

	const vueltas = 150
	arranque := make(chan struct{})
	var wg sync.WaitGroup

	wg.Add(1)
	go func() {
		defer wg.Done()
		<-arranque
		for i := 0; i < vueltas; i++ {
			SetDownloadDirectory(payloadDir)
			SetBackendConfig(`{"mode":"premium","stream_cache_max_mb":512}`)
			SetStreamCacheMaxMb(`{"mb":256}`)
			SetFlutterCallback("flutter-cb")
		}
	}()

	for r := 0; r < 3; r++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-arranque
			for i := 0; i < vueltas; i++ {
				_ = rutaDirPortadas()
				_ = streamCacheDirPath()
				_ = userLevelLabel()
				_ = streamCacheLevelLimitMB()
				_ = GetCallbackID()
			}
		}()
	}

	close(arranque)
	wg.Wait()
}

// escapeRutaJSON deja una ruta de Windows usable dentro de un JSON.
func escapeRutaJSON(ruta string) string {
	salida := make([]rune, 0, len(ruta))
	for _, c := range ruta {
		if c == '\\' {
			salida = append(salida, '\\', '\\')
			continue
		}
		salida = append(salida, c)
	}
	return string(salida)
}

// TestStressStreamerInstanciaUnica confirma que varios pedidos simultáneos de
// chunk comparten UNA instancia del servidor de streaming. Antes cada goroutine
// veía nil, creaba la suya y la última pisaba a la primera: el servidor que
// perdía la carrera quedaba vivo pero inalcanzable (puerto y caché perdidos).
func TestStressStreamerInstanciaUnica(t *testing.T) {
	// Arrancamos desde nil para que el test sea real y no pase porque otro test
	// ya había creado el servidor.
	streamerMu.Lock()
	previo := streamer
	streamer = nil
	streamerMu.Unlock()
	defer func() {
		streamerMu.Lock()
		streamer = previo
		streamerMu.Unlock()
	}()

	const goroutines = 16
	arranque := make(chan struct{})
	var mu sync.Mutex
	vistas := make([]tipoStreamer, 0, goroutines)
	var wg sync.WaitGroup

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-arranque
			srv := getStreamer()
			mu.Lock()
			vistas = append(vistas, srv)
			mu.Unlock()
		}()
	}

	close(arranque)
	wg.Wait()

	if len(vistas) != goroutines {
		t.Fatalf("esperaba %d instancias, obtuve %d", goroutines, len(vistas))
	}
	for i, srv := range vistas {
		if srv != vistas[0] {
			t.Fatalf("la instancia %d difiere de la primera: se crearon servidores duplicados", i)
		}
	}
}

// TestStressScrobbleClienteConcurrente: Flutter configura el scrobbling
// (SetupScrobbling) mientras UpdateNowPlaying/Scrobble pueden estar corriendo.
func TestStressScrobbleClienteConcurrente(t *testing.T) {
	previo := getScrobbleClient()
	defer setScrobbleClient(previo)

	const vueltas = 200
	arranque := make(chan struct{})
	var wg sync.WaitGroup

	wg.Add(1)
	go func() {
		defer wg.Done()
		<-arranque
		for i := 0; i < vueltas; i++ {
			setScrobbleClient(previo)
		}
	}()

	for r := 0; r < 3; r++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-arranque
			for i := 0; i < vueltas; i++ {
				_ = getScrobbleClient()
			}
		}()
	}

	close(arranque)
	wg.Wait()
}

// TestStressRegistroExtensionesConcurrente: el registro se reescribe en el
// ciclo de vida (InitExtensionSystem / LoadExtensionsFromDir, ambos RPC que
// Flutter puede repetir) mientras las acciones de extensión y el feed lo leen.
//
// El escritor guarda SIEMPRE el mismo valor a propósito: lo que se prueba es
// el acceso concurrente al campo, no el contenido.
func TestStressRegistroExtensionesConcurrente(t *testing.T) {
	previo := getExtRegistry()
	defer setExtRegistry(previo)

	const vueltas = 200
	arranque := make(chan struct{})
	var wg sync.WaitGroup

	wg.Add(1)
	go func() {
		defer wg.Done()
		<-arranque
		for i := 0; i < vueltas; i++ {
			setExtRegistry(previo)
		}
	}()

	for r := 0; r < 3; r++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-arranque
			for i := 0; i < vueltas; i++ {
				_ = getExtRegistry()
			}
		}()
	}

	close(arranque)
	wg.Wait()
}
