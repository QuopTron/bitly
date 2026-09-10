package bundled_extensions

import (
	"os"
	"path/filepath"
	"testing"
)

func TestVersionMasNueva(t *testing.T) {
	casos := []struct {
		nueva, instalada string
		esperado         bool
	}{
		{"1.2.10", "1.2.9", true},
		{"1.2.9", "1.2.10", false},
		{"2.0.0", "1.9.9", true},
		{"1.0.0", "1.0.0", false},
		{"v1.1.0", "1.0.0", true},
		{"1.0.0-beta", "0.9.0", true},
	}
	for _, c := range casos {
		if got := versionMasNueva(c.nueva, c.instalada); got != c.esperado {
			t.Errorf("versionMasNueva(%q,%q)=%v, esperado %v",
				c.nueva, c.instalada, got, c.esperado)
		}
	}
}

// El sincronizador debe escribir la extensión empaquetada cuando falta en
// disco y respetarla cuando la versión instalada es igual o más nueva.
func TestSincronizarConDisco(t *testing.T) {
	destino := t.TempDir()

	actualizadas := SincronizarConDisco(destino)
	if len(actualizadas) == 0 {
		t.Fatal("esperaba al menos una extensión sincronizada")
	}

	// Toda extensión sincronizada debe tener manifest + index.js en disco.
	for _, id := range actualizadas {
		manifest := filepath.Join(destino, id, "manifest.json")
		index := filepath.Join(destino, id, "index.js")
		if _, err := os.Stat(manifest); err != nil {
			t.Errorf("%s: falta manifest.json: %v", id, err)
		}
		if _, err := os.Stat(index); err != nil {
			t.Errorf("%s: falta index.js: %v", id, err)
		}
	}

	// Una segunda pasada no debe reescribir nada (ya están al día).
	if segunda := SincronizarConDisco(destino); len(segunda) != 0 {
		t.Errorf("segunda pasada reescribió %v, esperaba nada", segunda)
	}
}

// Una versión instalada más nueva en disco no debe ser pisada por la
// empaquetada (respeto por la copia del usuario).
func TestSincronizarRespetaVersionMasNuevaEnDisco(t *testing.T) {
	destino := t.TempDir()
	dirs, err := List()
	if err != nil || len(dirs) == 0 {
		t.Fatal("no hay extensiones empaquetadas")
	}
	id := dirs[0]
	raiz := filepath.Join(destino, id)
	if err := os.MkdirAll(raiz, 0o755); err != nil {
		t.Fatal(err)
	}
	marca := `{"name":"` + id + `","version":"99.0.0"}`
	if err := os.WriteFile(filepath.Join(raiz, "manifest.json"),
		[]byte(marca), 0o644); err != nil {
		t.Fatal(err)
	}

	SincronizarConDisco(destino)

	data, err := os.ReadFile(filepath.Join(raiz, "manifest.json"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != marca {
		t.Errorf("el manifest en disco fue pisado: %s", string(data))
	}
}
