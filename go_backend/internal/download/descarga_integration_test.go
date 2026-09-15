package download

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// ──────────────────────────────────────────────────────────────────────
// proveedorFalso — proveedor base que implementa provider.Provider con
// stubs vacíos. Solo los métodos que el test necesita son sobreescritos.
// ──────────────────────────────────────────────────────────────────────
type proveedorFalso struct {
	nombre         string
	streamURL      string
	streamErr      error
	track          *provider.TrackResult
	trackErr       error
	qualityOptions []string
}

func (p *proveedorFalso) Name() string { return p.nombre }
func (p *proveedorFalso) SearchTracks(string, int) ([]provider.TrackResult, error) {
	if p.track != nil {
		return []provider.TrackResult{*p.track}, nil
	}
	return nil, nil
}
func (p *proveedorFalso) SearchAlbums(string, int) ([]provider.AlbumResult, error)   { return nil, nil }
func (p *proveedorFalso) SearchArtists(string, int) ([]provider.ArtistResult, error) { return nil, nil }
func (p *proveedorFalso) SearchPlaylists(string, int) ([]provider.PlaylistResult, error) {
	return nil, nil
}
func (p *proveedorFalso) GetTrack(id string) (*provider.TrackResult, error) {
	if p.trackErr != nil {
		return nil, p.trackErr
	}
	if p.track != nil {
		return p.track, nil
	}
	return nil, fmt.Errorf("no track")
}
func (p *proveedorFalso) GetTrackByISRC(string) (*provider.TrackResult, error) {
	return p.GetTrack("")
}
func (p *proveedorFalso) GetAlbum(string) (*provider.AlbumResult, error) { return nil, nil }
func (p *proveedorFalso) GetArtist(string) (*provider.ArtistResult, error) {
	return nil, nil
}
func (p *proveedorFalso) GetStreamURL(trackID, quality string) (string, error) {
	if p.streamErr != nil {
		return "", p.streamErr
	}
	return p.streamURL, nil
}

// ──────────────────────────────────────────────────────────────────────
// proveedorArchivo — proveedor que trae su propio archivo (como Soulseek)
// ──────────────────────────────────────────────────────────────────────
type proveedorArchivo struct {
	proveedorFalso
	contenido []byte
	ext       string
	durS      int
}

func (p *proveedorArchivo) DescargarAArchivo(trackID, quality, destinoDir string, duracionEsperadaS int) (string, error) {
	p.durS = duracionEsperadaS
	if err := os.MkdirAll(destinoDir, 0o755); err != nil {
		return "", err
	}
	dest := filepath.Join(destinoDir, "test_track."+p.ext)
	if err := os.WriteFile(dest, p.contenido, 0o600); err != nil {
		return "", err
	}
	return dest, nil
}

// ──────────────────────────────────────────────────────────────────────
// proveedorLento — proveedor nativo cuyo stream tarda N ms (para tests
// de duplicado/override).
// ──────────────────────────────────────────────────────────────────────
type proveedorLento struct {
	proveedorFalso
	delay time.Duration
}

func (p *proveedorLento) GetStreamURL(trackID, quality string) (string, error) {
	time.Sleep(p.delay)
	if p.streamErr != nil {
		return "", p.streamErr
	}
	return p.streamURL, nil
}

// ──────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────

func audioFLAC() []byte {
	return append([]byte("fLaC"), make([]byte, 8192)...)
}

func audioMP3() []byte {
	return append([]byte{0xFF, 0xFB, 0x90, 0x00}, make([]byte, 8192)...)
}

func servidorStream(contenido []byte) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", fmt.Sprintf("%d", len(contenido)))
		w.WriteHeader(http.StatusOK)
		_, _ = io.Copy(w, strings.NewReader(string(contenido)))
	}))
}

func servidorStreamRange(contenido []byte) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Range") != "" {
			w.Header().Set("Content-Range", fmt.Sprintf("bytes 0-%d/%d", len(contenido)-1, len(contenido)))
			w.Header().Set("Content-Length", fmt.Sprintf("%d", len(contenido)))
			w.WriteHeader(http.StatusPartialContent)
			_, _ = io.Copy(w, strings.NewReader(string(contenido)))
			return
		}
		w.Header().Set("Content-Length", fmt.Sprintf("%d", len(contenido)))
		w.WriteHeader(http.StatusOK)
		_, _ = io.Copy(w, strings.NewReader(string(contenido)))
	}))
}

// ──────────────────────────────────────────────────────────────────────
// TEST 1: Descarga nativa (stream URL → archivo en disco)
// ──────────────────────────────────────────────────────────────────────
func TestIntDescargaNativaStream(t *testing.T) {
	srv := servidorStream(audioFLAC())
	defer srv.Close()

	p := &proveedorFalso{nombre: "int-native", streamURL: srv.URL + "/stream.flac"}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	outDir := t.TempDir()
	res := o.Download(Request{
		ItemID:    "int_native_1",
		Title:     "Canción Test",
		Artist:    "Artista Test",
		Provider:  "int-native",
		TrackID:   "native-id-1",
		Quality:   "LOSSLESS",
		OutputDir: outDir,
	})

	if !res.Success {
		t.Fatalf("descarga nativa falló: %s", res.Error)
	}
	if res.FilePath == "" {
		t.Fatal("no se devolvió filePath")
	}
	if _, err := os.Stat(res.FilePath); err != nil {
		t.Fatalf("archivo no existe: %v", err)
	}
	info, _ := os.Stat(res.FilePath)
	if info.Size() < 100 {
		t.Fatalf("archivo demasiado pequeño (%d bytes)", info.Size())
	}
	t.Logf("OK: nativa → %s (%d bytes)", filepath.Base(res.FilePath), info.Size())
}

// ──────────────────────────────────────────────────────────────────────
// TEST 2: Descarga con stream URL pero HTTP 404
// ──────────────────────────────────────────────────────────────────────
func TestIntDescarga404(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "not found", http.StatusNotFound)
	}))
	defer srv.Close()

	p := &proveedorFalso{nombre: "int-404", streamURL: srv.URL + "/missing.flac"}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	outDir := t.TempDir()
	res := o.Download(Request{
		ItemID:    "int_404",
		Provider:  "int-404",
		TrackID:   "id-404",
		OutputDir: outDir,
	})

	if res.Success {
		t.Fatal("debería haber fallado con HTTP 404")
	}
	t.Logf("OK: 404 detectado → %s", res.Error)
}

// ──────────────────────────────────────────────────────────────────────
// TEST 3: Descarga con stream URL pero HTTP 500
// ──────────────────────────────────────────────────────────────────────
func TestIntDescarga500(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "internal error", http.StatusInternalServerError)
	}))
	defer srv.Close()

	p := &proveedorFalso{nombre: "int-500", streamURL: srv.URL + "/error.flac"}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	outDir := t.TempDir()
	res := o.Download(Request{
		ItemID:    "int_500",
		Provider:  "int-500",
		TrackID:   "id-500",
		OutputDir: outDir,
	})

	if res.Success {
		t.Fatal("debería haber fallado con HTTP 500")
	}
	t.Logf("OK: 500 detectado → %s", res.Error)
}

// ──────────────────────────────────────────────────────────────────────
// TEST 4: Descarga con proveedor propio (Soulseek-like)
// ──────────────────────────────────────────────────────────────────────
func TestIntDescargaPropia(t *testing.T) {
	p := &proveedorArchivo{
		proveedorFalso: proveedorFalso{nombre: "int-propio"},
		contenido:      audioFLAC(),
		ext:            "flac",
	}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	outDir := t.TempDir()
	res := o.Download(Request{
		ItemID:     "int_propio_1",
		Title:      "Soulseek Track",
		Artist:     "Artista P2P",
		Provider:   "int-propio",
		TrackID:    "p2p-id-1",
		DurationMS: 210000,
		OutputDir:  outDir,
	})

	if !res.Success {
		t.Fatalf("descarga propia falló: %s", res.Error)
	}
	if res.FilePath == "" {
		t.Fatal("no se devolvió filePath")
	}
	t.Logf("OK: propia → %s", filepath.Base(res.FilePath))
}

// ──────────────────────────────────────────────────────────────────────
// TEST 5: Fallback de proveedor — el primero falla, el segundo tiene éxito
// ──────────────────────────────────────────────────────────────────────
func TestIntFallbackProveedor(t *testing.T) {
	srv := servidorStream(audioFLAC())
	defer srv.Close()

	// El provider owner (int-fallo) tiene TrackID, así que lo resuelve
	// directamente en resolverTrackIDProvider (name == req.Provider).
	// El provider secundario (int-ok) NO es owner, así que necesita poder
	// resolver por GetTrack (cross-provider id o search por nombre).
	track := &provider.TrackResult{ID: "fallo-id-1", Title: "Canción", Artist: "Artista"}
	pFallo := &proveedorFalso{
		nombre:    "int-fallo",
		streamErr: fmt.Errorf("network timeout"),
		track:     track,
	}
	pOk := &proveedorFalso{
		nombre:    "int-ok",
		streamURL: srv.URL + "/fallback.flac",
		track:     track,
	}
	reg := provider.NewRegistry()
	reg.Register(pFallo)
	reg.Register(pOk)
	o := NewOrchestrator(reg)
	o.SetFallbackOrder([]string{"int-fallo", "int-ok"})

	outDir := t.TempDir()
	res := o.Download(Request{
		ItemID:    "int_fallback_1",
		Title:     "Canción",
		Artist:    "Artista",
		Provider:  "int-fallo",
		TrackID:   "fallo-id-1",
		OutputDir: outDir,
	})

	if !res.Success {
		t.Fatalf("fallback falló: %s", res.Error)
	}
	if res.Provider == "int-fallo" {
		t.Fatal("el provider ganador debería ser int-ok, no int-fallo")
	}
	t.Logf("OK: fallback de int-fallo → int-ok (%s)", filepath.Base(res.FilePath))
}

// ──────────────────────────────────────────────────────────────────────
// TEST 6: Todos los proveedores fallan
// ──────────────────────────────────────────────────────────────────────
func TestIntTodosFallan(t *testing.T) {
	p1 := &proveedorFalso{nombre: "int-f1", streamErr: fmt.Errorf("error 1")}
	p2 := &proveedorFalso{nombre: "int-f2", streamErr: fmt.Errorf("error 2")}
	p3 := &proveedorFalso{nombre: "int-f3", streamErr: fmt.Errorf("error 3")}

	reg := provider.NewRegistry()
	reg.Register(p1)
	reg.Register(p2)
	reg.Register(p3)
	o := NewOrchestrator(reg)
	o.SetFallbackOrder([]string{"int-f1", "int-f2", "int-f3"})

	outDir := t.TempDir()
	res := o.Download(Request{
		ItemID:    "int_all_fail",
		Provider:  "int-f1",
		TrackID:   "all-fail-id",
		OutputDir: outDir,
	})

	if res.Success {
		t.Fatal("debería fallar cuando todos los providers fallan")
	}
	t.Logf("OK: todos fallan → %s", res.Error)
}

// ──────────────────────────────────────────────────────────────────────
// TEST 7: Descarga con Range resume
// ──────────────────────────────────────────────────────────────────────
func TestIntRangeResume(t *testing.T) {
	srv := servidorStreamRange(audioFLAC())
	defer srv.Close()

	p := &proveedorFalso{nombre: "int-range", streamURL: srv.URL + "/resume.flac"}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	outDir := t.TempDir()
	res := o.Download(Request{
		ItemID:    "int_range_1",
		Provider:  "int-range",
		TrackID:   "range-id-1",
		OutputDir: outDir,
	})

	if !res.Success {
		t.Fatalf("descarga con range falló: %s", res.Error)
	}
	t.Logf("OK: range → %s", filepath.Base(res.FilePath))
}

// ──────────────────────────────────────────────────────────────────────
// TEST 8: Descarga duplicada —同一 item bloqueado concurrentemente
// ──────────────────────────────────────────────────────────────────────
func TestIntDuplicadoConcurrente(t *testing.T) {
	// Proveedor lento: toma 200ms en resolver, para que el segundo request
	// llegue mientras el primero sigue activo.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(50 * time.Millisecond)
		data := audioFLAC()
		w.Header().Set("Content-Length", fmt.Sprintf("%d", len(data)))
		w.WriteHeader(http.StatusOK)
		_, _ = io.Copy(w, strings.NewReader(string(data)))
	}))
	defer srv.Close()

	p := &proveedorLento{
		proveedorFalso: proveedorFalso{nombre: "int-slow", streamURL: srv.URL + "/slow.flac"},
		delay:          200 * time.Millisecond,
	}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	outDir := t.TempDir()
	req := Request{
		ItemID:    "int_dup_1",
		Provider:  "int-slow",
		TrackID:   "dup-id-1",
		OutputDir: outDir,
	}

	var mu sync.Mutex
	var r1, r2 *Result
	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		defer wg.Done()
		res := o.Download(req)
		mu.Lock()
		r1 = res
		mu.Unlock()
	}()
	// Esperar un poco para que el primero tome el lock y empiece a descargar.
	time.Sleep(30 * time.Millisecond)
	go func() {
		defer wg.Done()
		res := o.Download(req)
		mu.Lock()
		r2 = res
		mu.Unlock()
	}()

	wg.Wait()
	mu.Lock()
	defer mu.Unlock()

	if r1 == nil || !r1.Success {
		t.Fatalf("primera descarga falló: %v", r1)
	}
	if r2 == nil {
		t.Fatal("segunda descarga devolvió nil")
	}
	if r2.Success {
		t.Fatal("la segunda descarga debería haber sido rechazada (already downloading)")
	}
	if !strings.Contains(r2.Error, "already downloading") {
		t.Fatalf("error inesperado: %s", r2.Error)
	}
	t.Logf("OK: duplicado bloqueado → %s", r2.Error)
}

// ──────────────────────────────────────────────────────────────────────
// TEST 9: Fallback de calidad — pedido LOSSLESS pero solo hay MP3
// ──────────────────────────────────────────────────────────────────────
func TestIntFallbackCalidad(t *testing.T) {
	srv := servidorStream(audioMP3())
	defer srv.Close()

	p := &proveedorFalso{
		nombre:         "int-quality",
		streamURL:      srv.URL + "/quality.mp3",
		qualityOptions: []string{"MP3_128", "MP3_320"},
	}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	outDir := t.TempDir()
	res := o.Download(Request{
		ItemID:    "int_quality_1",
		Provider:  "int-quality",
		TrackID:   "quality-id-1",
		Quality:   "LOSSLESS",
		OutputDir: outDir,
	})

	if !res.Success {
		t.Fatalf("fallback de calidad falló: %s", res.Error)
	}
	t.Logf("OK: calidad fallback → %s", filepath.Base(res.FilePath))
}

// ──────────────────────────────────────────────────────────────────────
// TEST 10: Batch download — múltiples tracks en paralelo
// ──────────────────────────────────────────────────────────────────────
func TestIntBatch(t *testing.T) {
	srv := servidorStream(audioFLAC())
	defer srv.Close()

	p := &proveedorFalso{nombre: "int-batch", streamURL: srv.URL + "/batch.flac"}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	outDir := t.TempDir()
	requests := make([]Request, 5)
	for i := range requests {
		requests[i] = Request{
			ItemID:    fmt.Sprintf("int_batch_%d", i),
			Provider:  "int-batch",
			TrackID:   fmt.Sprintf("batch-id-%d", i),
			OutputDir: outDir,
		}
	}

	results := o.DownloadBatch(requests)
	for i, res := range results {
		if !res.Success {
			t.Fatalf("batch[%d] falló: %s", i, res.Error)
		}
	}
	t.Logf("OK: batch de %d tracks", len(results))
}

// ──────────────────────────────────────────────────────────────────────
// TEST 11: Stream corrupto (no es audio)
// ──────────────────────────────────────────────────────────────────────
func TestIntStreamCorrupto(t *testing.T) {
	srv := servidorStream([]byte("esto no es un archivo de audio es basura"))
	defer srv.Close()

	p := &proveedorFalso{nombre: "int-corrupt", streamURL: srv.URL + "/corrupt.flac"}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	outDir := t.TempDir()
	res := o.Download(Request{
		ItemID:    "int_corrupt_1",
		Provider:  "int-corrupt",
		TrackID:   "corrupt-id-1",
		OutputDir: outDir,
	})

	if res.Success {
		t.Fatal("debería haber rechazado stream corrupto")
	}
	t.Logf("OK: corrupto rechazado → %s", res.Error)
}

// ──────────────────────────────────────────────────────────────────────
// TEST 12: Sin outputDir → devuelve streamURL
// ──────────────────────────────────────────────────────────────────────
func TestIntSinOutputDir(t *testing.T) {
	p := &proveedorFalso{nombre: "int-nodir", streamURL: "https://example.com/stream.flac"}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	res := o.Download(Request{
		ItemID:   "int_nodir_1",
		Provider: "int-nodir",
		TrackID:  "nodir-id-1",
	})

	if !res.Success {
		t.Fatalf("sin output dir debería devolver streamURL: %s", res.Error)
	}
	if res.StreamURL == "" {
		t.Fatal("debería devolver streamURL")
	}
	t.Logf("OK: sin dir → streamURL=%s", res.StreamURL)
}

// ──────────────────────────────────────────────────────────────────────
// TEST 13: Provider sin streamURL ni DescargarAArchivo
// ──────────────────────────────────────────────────────────────────────
func TestIntSinCapabilities(t *testing.T) {
	p := &proveedorFalso{nombre: "int-nocap", streamErr: fmt.Errorf("no capabilities")}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	outDir := t.TempDir()
	res := o.Download(Request{
		ItemID:    "int_nocap_1",
		Provider:  "int-nocap",
		TrackID:   "nocap-id-1",
		OutputDir: outDir,
	})

	if res.Success {
		t.Fatal("debería fallar sin capabilities")
	}
	t.Logf("OK: sin capabilities → %s", res.Error)
}

// ──────────────────────────────────────────────────────────────────────
// TEST 14: Proveedor propio con duración correcta
// ──────────────────────────────────────────────────────────────────────
func TestIntPropioConDuracion(t *testing.T) {
	p := &proveedorArchivo{
		proveedorFalso: proveedorFalso{nombre: "int-propio-dur"},
		contenido:      audioFLAC(),
		ext:            "flac",
	}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	outDir := t.TempDir()
	res := o.Download(Request{
		ItemID:     "int_propio_dur",
		Title:      "Track con duración",
		Provider:   "int-propio-dur",
		TrackID:    "dur-id-1",
		DurationMS: 180000, // 3 minutos
		OutputDir:  outDir,
	})

	if !res.Success {
		t.Fatalf("descarga propia con duración falló: %s", res.Error)
	}
	if p.durS != 180 {
		t.Fatalf("duración no pasada correctamente: esperaba 180s, obtuve %d", p.durS)
	}
	t.Logf("OK: propia con duración=%ds → %s", p.durS, filepath.Base(res.FilePath))
}
