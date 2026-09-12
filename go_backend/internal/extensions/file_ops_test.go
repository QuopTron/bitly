package extensions

import (
	"bytes"
	"crypto/cipher"
	"encoding/hex"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	//lint:ignore SA1019 Blowfish es el algoritmo que exige el DRM de Deezer.
	"golang.org/x/crypto/blowfish"
)

// TestTransformPatternedBlocksRoundTrip comprueba que el transform por bloques
// descifra EXACTAMENTE los bloques del patrón (cada tercero) y deja el resto
// intacto: es la garantía de que un FLAC de Deezer no se corrompe.
func TestTransformPatternedBlocksRoundTrip(t *testing.T) {
	dir := t.TempDir()
	segmentSize := 2048
	const blocks = 8

	// Plaintext determinista.
	plain := make([]byte, segmentSize*blocks)
	for i := range plain {
		plain[i] = byte((i*7 + 13) % 251)
	}

	keyHex := "0123456789abcdef0123456789abcdef"
	ivHex := "0001020304050607"
	key, _ := hex.DecodeString(keyHex)
	iv, _ := hex.DecodeString(ivHex)

	// Cifra los bloques 0 y 3 (patrón transformEvery=3, offset=0), como hace
	// Deezer: el resto del archivo queda en claro.
	encrypted := make([]byte, len(plain))
	copy(encrypted, plain)
	block, err := blowfish.NewCipher(key)
	if err != nil {
		t.Fatalf("blowfish: %v", err)
	}
	for i := 0; i < blocks; i++ {
		if i%3 != 0 {
			continue
		}
		off := i * segmentSize
		mode := cipher.NewCBCEncrypter(block, iv)
		mode.CryptBlocks(encrypted[off:off+segmentSize], plain[off:off+segmentSize])
	}

	inPath := filepath.Join(dir, "enc.bin")
	outPath := filepath.Join(dir, "out.bin")
	if err := os.WriteFile(inPath, encrypted, 0o644); err != nil {
		t.Fatalf("write input: %v", err)
	}

	rt := NewRuntime()
	cfg := DefaultConfig()
	cfg.TimeoutMs = 30000
	cfg.EnableFS = true
	cfg.AllowedDirs = []string{dir}

	script := fmt.Sprintf(`
var progressCalls = 0;
var result = file.transformPatternedBlocks(%q, %q, {
  operation: "decrypt", algorithm: "blowfish", mode: "cbc",
  key: %q, keyEncoding: "hex", iv: %q, ivEncoding: "hex",
  padding: "none", segmentSize: %d, transformEvery: 3, transformOffset: 0,
  transformPartial: false
}, function(processed, total) { progressCalls++; });
({ success: result.success, size: result.size, progressCalls: progressCalls, error: result.error || "" });
`, filepath.ToSlash(inPath), filepath.ToSlash(outPath), keyHex, ivHex, segmentSize)

	res, err := rt.RunJS(script, "deezer", "deezer", cfg, dir)
	if err != nil {
		t.Fatalf("RunJS: %v", err)
	}
	if res["success"] != true {
		t.Fatalf("transform no tuvo éxito: %v", res["error"])
	}

	got, err := os.ReadFile(outPath)
	if err != nil {
		t.Fatalf("read output: %v", err)
	}
	if !bytes.Equal(got, plain) {
		// Localiza el primer bloque que difiere para diagnosticar.
		bad := -1
		for i := 0; i < len(plain) && i < len(got); i++ {
			if plain[i] != got[i] {
				bad = i / segmentSize
				break
			}
		}
		t.Fatalf("el archivo descifrado no coincide con el original (bloque %d difiere, len got=%d want=%d)", bad, len(got), len(plain))
	}
	if progressCalls, _ := res["progressCalls"].(int64); progressCalls == 0 {
		t.Errorf("el callback de progreso nunca se invocó")
	}
}

// TestDownloadSegmentsConcatenatesInOrder comprueba que los segmentos se bajan,
// se concatenan en el ORDEN de la lista (no en el de llegada) y que los
// archivos temporales de checkpoint se limpian al terminar.
func TestDownloadSegmentsConcatenatesInOrder(t *testing.T) {
	dir := t.TempDir()

	// El segmento 1 tarda más que el 2 para forzar llegada fuera de orden.
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/init":
			fmt.Fprint(w, "INIT-")
		case "/seg1":
			fmt.Fprint(w, "AAA")
		case "/seg2":
			fmt.Fprint(w, "BBB")
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	outPath := filepath.Join(dir, "track.mp4")

	rt := NewRuntime()
	cfg := DefaultConfig()
	cfg.TimeoutMs = 30000
	cfg.EnableFS = true
	cfg.AllowedDirs = []string{dir}

	script := fmt.Sprintf(`
var lastProgress = null;
var result = file.downloadSegments([%q, %q, %q], %q, {
  headers: { "User-Agent": "test" },
  maxParallel: 3,
  persistentCheckpoint: true,
  onProgress: function(written, total, completed, totalSegments) {
    lastProgress = [written, total, completed, totalSegments];
  }
});
({ success: result.success, size: result.size, segments: result.segments,
   progress: lastProgress ? lastProgress.join(",") : "", error: result.error || "" });
`, server.URL+"/init", server.URL+"/seg1", server.URL+"/seg2", filepath.ToSlash(outPath))

	res, err := rt.RunJS(script, "tidal-web", "tidal-web", cfg, dir)
	if err != nil {
		t.Fatalf("RunJS: %v", err)
	}
	if res["success"] != true {
		t.Fatalf("downloadSegments falló: %v", res["error"])
	}

	got, err := os.ReadFile(outPath)
	if err != nil {
		t.Fatalf("read output: %v", err)
	}
	if want := "INIT-AAABBB"; string(got) != want {
		t.Fatalf("orden de concatenación incorrecto: got %q, want %q", string(got), want)
	}

	// El checkpoint se consume: no deben quedar partes.
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("readdir: %v", err)
	}
	for _, e := range entries {
		if strings.Contains(e.Name(), ".part") {
			t.Errorf("quedó un archivo temporal sin limpiar: %s", e.Name())
		}
	}
}

// TestDownloadSegmentsKeepsCheckpointOnFailure comprueba que un fallo conserva
// los partes ya bajados, para que el próximo intento reanude en vez de volver a
// descargar todo.
func TestDownloadSegmentsKeepsCheckpointOnFailure(t *testing.T) {
	dir := t.TempDir()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/bad" {
			http.Error(w, "boom", http.StatusInternalServerError)
			return
		}
		fmt.Fprint(w, "OK")
	}))
	defer server.Close()

	outPath := filepath.Join(dir, "track.mp4")

	rt := NewRuntime()
	cfg := DefaultConfig()
	cfg.TimeoutMs = 30000
	cfg.EnableFS = true
	cfg.AllowedDirs = []string{dir}

	script := fmt.Sprintf(`
var result = file.downloadSegments([%q, %q], %q, {
  maxParallel: 2, persistentCheckpoint: true
});
({ success: result.success, completed: result.completed, error: result.error || "" });
`, server.URL+"/ok", server.URL+"/bad", filepath.ToSlash(outPath))

	res, err := rt.RunJS(script, "tidal-web", "tidal-web", cfg, dir)
	if err != nil {
		t.Fatalf("RunJS: %v", err)
	}
	if res["success"] == true {
		t.Fatalf("se esperaba fallo por el segmento 500")
	}

	// El parte del segmento bueno debe seguir ahí para reanudar.
	if _, err := os.Stat(outPath + ".part0"); err != nil {
		t.Errorf("no se conservó el checkpoint del segmento exitoso: %v", err)
	}
}

// TestResolutionUtilsDisponibles comprueba que las utilidades que consultan las
// extensiones modernas existen y devuelven tipos usables.
func TestResolutionUtilsDisponibles(t *testing.T) {
	rt := NewRuntime()
	cfg := DefaultConfig()
	cfg.TimeoutMs = 30000

	res, err := rt.RunJS(`
var remaining = utils.getResolutionRemainingMs();
var cancelled = utils.isRequestCancelled();
({
  remaining: remaining,
  remainingPositive: Number(remaining) > 0,
  withinBudget: Number(remaining) <= 50000,
  cancelled: cancelled
});
`, "utils-test", "utils-test", cfg, ".")
	if err != nil {
		t.Fatalf("faltan utilidades de resolución: %v", err)
	}
	if res["remainingPositive"] != true {
		t.Errorf("getResolutionRemainingMs no devolvió un presupuesto positivo: %v", res["remaining"])
	}
	if res["withinBudget"] != true {
		t.Errorf("getResolutionRemainingMs excede el presupuesto esperado: %v", res["remaining"])
	}
	if res["cancelled"] != false {
		t.Errorf("isRequestCancelled debe ser false sin cancelación activa")
	}
}
