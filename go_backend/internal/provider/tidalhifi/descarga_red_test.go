package tidalhifi

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/audio"
)

// descarga_red_test.go — Prueba CONTRA TIDAL REAL, apagada por defecto.
//
// Por qué: los tests de manifiesto_test.go fijan el desarmado con datos
// recortados, pero no prueban que el canal siga vivo ni que el FLAC armado se
// pueda decodificar. Esta prueba baja una canción completa (16 MB) y la
// inspecciona con el mismo lector que usa el backend.
//
// Se activa a mano:
//
//	BITLY_TIDAL_HIFI=1 go test ./internal/provider/tidalhifi/ -run TestDescargaReal -v
//
// No corre en la batería normal ni en los workflows: depende de un tercero.
func TestDescargaRealDejaUnFLACValido(t *testing.T) {
	if os.Getenv("BITLY_TIDAL_HIFI") == "" {
		t.Skip("define BITLY_TIDAL_HIFI=1 para probar el canal real")
	}
	dir := t.TempDir()
	cliente := NewClient()
	// "NUEVAYoL" de Bad Bunny: ISRC y duración del catálogo.
	ruta, err := cliente.DescargarPista("", "QMFMF2447055", "NUEVAYoL", "Bad Bunny",
		"LOSSLESS", dir, 184)
	if err != nil {
		t.Fatalf("no se pudo bajar: %v", err)
	}
	info, err := os.Stat(ruta)
	if err != nil {
		t.Fatalf("no quedó el archivo: %v", err)
	}
	t.Logf("archivo: %s (%d bytes)", filepath.Base(ruta), info.Size())
	meta, err := audio.ReadFileMetadata(ruta)
	if err != nil {
		t.Fatalf("el archivo no se puede leer como audio: %v", err)
	}
	if meta.Format != "flac" {
		t.Fatalf("no es FLAC: %q", meta.Format)
	}
	if meta.SampleRate != 44100 || meta.DurationMs < 180000 || meta.DurationMs > 190000 {
		t.Fatalf("audio inesperado: %d Hz, %d ms", meta.SampleRate, meta.DurationMs)
	}
	// El nombre del archivo debe ser el de la canción, no un id.
	if filepath.Ext(ruta) != ".flac" {
		t.Fatalf("extensión inesperada: %s", ruta)
	}
}
