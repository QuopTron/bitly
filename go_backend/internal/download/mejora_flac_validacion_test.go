package download

// mejora_flac_validacion_test.go — Fija la VALIDACIÓN del FLAC mejorado: que el
// archivo sea FLAC de verdad, que la duración se lea del propio archivo y que el
// reemplazo deje uno solo (el nuevo) en la carpeta.

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestEsFLACSinPerdida(t *testing.T) {
	dir := t.TempDir()

	bueno := filepath.Join(dir, "baja.flac")
	flacFalso(t, bueno, 44100, 44100*180)
	if ok, motivo := esFLACSinPerdida(bueno); !ok {
		t.Fatalf("un FLAC real no debería rechazarse: %s", motivo)
	}

	mp3 := filepath.Join(dir, "cancion.mp3")
	datos := append([]byte("ID3\x04\x00\x00\x00"), make([]byte, 200)...)
	if err := os.WriteFile(mp3, datos, 0o644); err != nil {
		t.Fatal(err)
	}
	if ok, motivo := esFLACSinPerdida(mp3); ok || !strings.Contains(motivo, "mp3") {
		t.Fatalf("un MP3 no puede pasar como FLAC (ok=%v, motivo=%q)", ok, motivo)
	}

	basura := filepath.Join(dir, "cancion.flac")
	if err := os.WriteFile(basura, append([]byte("<html>x"), make([]byte, 200)...), 0o644); err != nil {
		t.Fatal(err)
	}
	if ok, _ := esFLACSinPerdida(basura); ok {
		t.Fatal("una página web renombrada a .flac no puede pasar")
	}
}

func TestDuracionFLACDesdeStreaminfo(t *testing.T) {
	dir := t.TempDir()
	ruta := filepath.Join(dir, "cancion.flac")
	flacFalso(t, ruta, 44100, 44100*180) // 180 s exactos
	if ms := duracionFLACMs(ruta); ms != 180000 {
		t.Fatalf("duración = %d ms, quería 180000", ms)
	}
	if ms := duracionFLACMs(filepath.Join(dir, "no-existe.flac")); ms != 0 {
		t.Fatalf("un archivo ausente debe dar 0, dio %d", ms)
	}
}

func TestReemplazarPorFLACDejaElNuevoYBorraElViejo(t *testing.T) {
	dir := t.TempDir()
	viejo := filepath.Join(dir, "track_1_audio.m4a")
	if err := os.WriteFile(viejo, make([]byte, 256), 0o644); err != nil {
		t.Fatal(err)
	}
	nuevo := filepath.Join(dir, ".descarga.tmp.flac")
	flacFalso(t, nuevo, 44100, 44100*180)

	o := &Orchestrator{tracker: NewTracker()}
	o.tracker.Add("track_1_audio", "NUEVAYoL", "ytmusic-spotiflac")
	// Sin metadata en la petición el etiquetado no se dispara (es best-effort y
	// acá solo se verifica el reemplazo del archivo).
	trabajo := trabajoMejoraFLAC{
		req:        Request{ItemID: "track_1_audio"},
		rutaActual: viejo,
	}
	if err := o.reemplazarPorFLAC(trabajo, nuevo, "internetarchive"); err != nil {
		t.Fatalf("reemplazo falló: %v", err)
	}

	destino := rutaFLACPara(viejo)
	if _, err := os.Stat(destino); err != nil {
		t.Fatalf("el FLAC no quedó en %s: %v", destino, err)
	}
	if _, err := os.Stat(viejo); !os.IsNotExist(err) {
		t.Fatal("el archivo con pérdida debía borrarse")
	}
	if _, err := os.Stat(nuevo); !os.IsNotExist(err) {
		t.Fatal("el temporal del FLAC debía desaparecer")
	}
	p := o.tracker.Get("track_1_audio")
	if p == nil || p.OutputPath != destino {
		t.Fatalf("el tracker debe publicar el path nuevo, quedó %+v", p)
	}
	if p.Status != StatusCompleted {
		t.Fatalf("el estado debía seguir completado, quedó %v", p.Status)
	}
}

func TestRutaFLACParaSoloCambiaLaExtension(t *testing.T) {
	if got := rutaFLACPara("/m/1Q9E_audio.m4a"); got != "/m/1Q9E_audio.flac" {
		t.Fatalf("ruta = %q", got)
	}
	if got := rutaFLACPara("/m/tema"); got != "/m/tema.flac" {
		t.Fatalf("sin extensión debería agregarla: %q", got)
	}
}
