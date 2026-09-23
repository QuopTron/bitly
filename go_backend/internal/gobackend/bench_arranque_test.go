// bench_arranque_test.go — Costo del arranque del backend Go.
//
// InitGlobalState() es el arranque completo: carga las extensiones empaquetadas
// (lectura de disco + registro), registra los proveedores nativos, cablea el
// motor de búsqueda, el orquestador de descargas, rescate, letras, playback,
// premium, sesiones y los managers auxiliares. Lo llama Flutter una vez por
// proceso, así que su costo es tiempo puro de "pantalla de arranque".
//
// Dos sub-benchmarks para saber DÓNDE se va el tiempo:
//
//	Completo         InitGlobalState() entero, tal como lo llama la app.
//	Solo_servicios   solo el cableado de los servicios (búsqueda, descarga,
//	                 rescate, letras, playback...), sin extensiones ni
//	                 proveedores. La resta contra el completo dice cuánto del
//	                 arranque es carga de extensiones desde disco.
//
// Se corre con:
//
//	go test ./internal/gobackend -run '^$' -bench BenchmarkArranque -benchmem
package gobackend

import (
	"io"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/recommend"
	"github.com/zarz/bitly/go_backend/internal/rescue"
	"github.com/zarz/bitly/go_backend/internal/search"
)

// sufijoExeBench replica el sufijo del paquete bin (que es interno) para poder
// crear los binarios falsos con el nombre que espera el manager.
func sufijoExeBench() string {
	if runtime.GOOS == "windows" {
		return ".exe"
	}
	return ""
}

// prepararBinariosArranque deja BITLY_BIN_DIR apuntando a un directorio con
// yt-dlp y ffmpeg que ya "existen y son válidos", y BITLY_EXT_DIR a una carpeta
// temporal.
//
// Por qué el de binarios: InitGlobalState lanza en segundo plano la descarga de
// esas herramientas. En una máquina sin ellas, cada iteración del benchmark
// saldría a la RED y mediría latencia de internet en vez de arranque. Con los
// archivos presentes, EnsureYTDLP/EnsureFFmpeg retornan al instante (es lo que
// pasa en cualquier arranque normal después del primero).
//
// Por qué el de extensiones: para que el benchmark no escriba en la carpeta de
// configuración REAL del usuario. El estado estacionario es el mismo que en el
// aparato (el warm-up deja las extensiones ya sincronizadas en disco).
//
// esBinarioValido exige >100 KB y la cabecera del formato de la plataforma
// (PE "MZ" en Windows, ELF en Linux/Android, Mach-O en macOS), así que los
// archivos de relleno se crean con esa forma exacta.
func prepararBinariosArranque(b testing.TB) {
	b.Helper()
	dir := b.TempDir()
	b.Setenv("BITLY_EXT_DIR", b.TempDir())

	relleno := make([]byte, 128<<10)
	switch runtime.GOOS {
	case "windows":
		copy(relleno, []byte("MZ"))
	case "darwin":
		copy(relleno, []byte{0xFE, 0xED, 0xFA, 0xCE})
	default:
		copy(relleno, []byte{0x7F, 'E', 'L', 'F'})
	}

	for _, nombre := range []string{"yt-dlp", "ffmpeg"} {
		ruta := filepath.Join(dir, nombre+sufijoExeBench())
		if err := os.WriteFile(ruta, relleno, 0o755); err != nil {
			b.Fatalf("no se pudo crear %s: %v", ruta, err)
		}
	}

	b.Setenv("BITLY_BIN_DIR", dir)
}

// BenchmarkArranqueCompleto mide el arranque tal como lo llama la app.
func BenchmarkArranqueCompleto(b *testing.B) {
	prepararBinariosArranque(b)
	// El loader de extensiones imprime una línea por extensión en cada pasada:
	// sin silenciarlo, la salida del benchmark es ilegible. En el aparato eso va
	// a logcat, así que tampoco es lo que se quiere medir.
	silenciarLogArranque(b)
	// AjustarRuntimeMemoria (parte del arranque) acota GOMAXPROCS para no
	// saturar la CPU del dispositivo y no lo restaura: es a propósito. Acá sí se
	// restaura, para que el benchmark no le deje el límite puesto a los que
	// corren después en el mismo proceso.
	previoGOMAXPROCS := runtime.GOMAXPROCS(0)
	b.Cleanup(func() { runtime.GOMAXPROCS(previoGOMAXPROCS) })

	// Una pasada fuera de la medición: la primera carga lee las extensiones
	// con la caché del sistema de archivos fría. Medir eso mezclaría el costo
	// del disco con el del arranque repetido (y en la app el archivo ya está
	// en caché del SO casi siempre).
	if InitGlobalState() == "" {
		b.Fatal("el arranque no devolvió respuesta")
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if InitGlobalState() == "" {
			b.Fatal("el arranque no devolvió respuesta")
		}
	}
}

// silenciarLogArranque apaga el logger durante el benchmark y lo restaura al
// terminar.
func silenciarLogArranque(b testing.TB) {
	b.Helper()
	previo := log.Writer()
	log.SetOutput(io.Discard)
	b.Cleanup(func() { log.SetOutput(previo) })
}

// BenchmarkArranqueSoloServicios mide el arranque SIN extensiones ni
// proveedores: solo construir y cablear los servicios. La resta contra el
// benchmark de arriba es el costo real de cargar las extensiones.
func BenchmarkArranqueSoloServicios(b *testing.B) {
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		reg := provider.NewRegistry()
		searchEngine = search.New(reg, search.DefaultConfig())
		downloadOrch = download.NewOrchestrator(reg)
		rescueSvc = rescue.New(reg)
		enricher = rescue.NewEnricher(reg)
		recommendEng = recommend.New(reg)
		lyricsClient = lyrics.NewClient()
	}
}
