package download

import (
	"os"
	"path/filepath"
	"testing"
)

// El guard solo puede RECHAZAR cuando confirma que el archivo es un clip: sin
// duración de catálogo, sin archivo o sin duración legible tiene que ACEPTAR,
// o cualquier descarga de un formato encriptado (duración ilegible) se
// descartaría sola.
func TestDuracionPlausibleAceptaSinDatos(t *testing.T) {
	tmp := filepath.Join(t.TempDir(), "cancion.flac")
	if err := os.WriteFile(tmp, []byte("no es flac"), 0o644); err != nil {
		t.Fatal(err)
	}

	casos := []struct {
		nombre   string
		path     string
		catalogo int
	}{
		{"sin path", "", 240000},
		{"catálogo corto (no se aplica)", tmp, 45000},
		{"catálogo desconocido", tmp, 0},
		{"archivo inexistente", filepath.Join(t.TempDir(), "nada.flac"), 240000},
		{"archivo sin duración legible", tmp, 240000},
	}
	for _, c := range casos {
		if !esDuracionPlausible(c.path, c.catalogo) {
			t.Errorf("%s: se rechazó una candidata sin datos para juzgar", c.nombre)
		}
	}
}
