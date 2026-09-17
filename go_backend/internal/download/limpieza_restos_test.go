// limpieza_restos_test.go — Fija que la limpieza de restos borre SOLO lo
// inservible. Es la mitad que importa: si borrara de más, tiraría el parcial
// reanudable de una descarga que iba a continuar (el usuario perdería el
// trabajo ya bajado); si borrara de menos, seguirían acumulándose en su
// carpeta los temporales de cientos de MB que motivaron este código.
//
// Se conecta con: limpieza_restos.go.
// Parte del flujo: descarga de audio a disco.
package download

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestLimpiezaBorraRestosInserviblesYConservaLoReanudable(t *testing.T) {
	dir := t.TempDir()
	escribir := func(nombre string, viejo bool) string {
		ruta := filepath.Join(dir, nombre)
		if err := os.WriteFile(ruta, []byte("x"), 0o644); err != nil {
			t.Fatalf("no se pudo crear %s: %v", nombre, err)
		}
		if viejo {
			antiguo := time.Now().Add(-time.Hour)
			_ = os.Chtimes(ruta, antiguo, antiguo)
		}
		return ruta
	}

	// Inservibles: temporales de la descarga por tramos, copia de etiquetado
	// interrumpida y resto del staging.
	paralelo := escribir("dl-par-4NRXx6U8ABQ-a7a9-4234.mp3", true)
	etiqueta := escribir(".Blinding Lights.tags.partial.mp3", true)
	staging := escribir("cancion.partial", true)

	// Reanudable: un parcial secuencial viejo NO se toca (continuar la descarga
	// es justamente lo que se quiere).
	reanudable := escribir("dl-134858527-deadbeef-99.mp3", true)
	// Recién escrito: podría estar bajando en este instante, no se toca.
	enVuelo := escribir("dl-par-blah-blah-11.mp3", false)
	// La descarga terminada, obviamente, se queda.
	final := escribir("Blinding Lights.mp3", true)

	borrados := limpiarRestosDescarga(dir)
	if borrados != 3 {
		t.Fatalf("esperaba 3 borrados, hubo %d", borrados)
	}
	for _, ruta := range []string{paralelo, etiqueta, staging} {
		if _, err := os.Stat(ruta); err == nil {
			t.Errorf("debía borrarse y sigue ahí: %s", filepath.Base(ruta))
		}
	}
	for _, ruta := range []string{reanudable, enVuelo, final} {
		if _, err := os.Stat(ruta); err != nil {
			t.Errorf("no debía borrarse y falta: %s", filepath.Base(ruta))
		}
	}
}

func TestEsRestoInservible(t *testing.T) {
	casos := map[string]bool{
		"dl-par-abc-123-456.flac":    true,
		".cancion.tags.partial.flac": true,
		"algo.partial":               true,
		"dl-123-deadbeef-99.flac":    false,
		"Blinding Lights.mp3":        false,
		"cancion.flac":               false,
	}
	for nombre, esperado := range casos {
		if got := esRestoInservible(nombre); got != esperado {
			t.Errorf("esRestoInservible(%q) = %v, esperaba %v", nombre, got, esperado)
		}
	}
}
