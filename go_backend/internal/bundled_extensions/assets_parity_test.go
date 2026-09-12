// assets_parity_test.go — Guard contra el drift entre las DOS copias trackeadas
// de las extensiones.
//
// En el repo hay dos copias y las dos se usan:
//
//   - assets/extensions/           → la empaqueta Flutter; en Android estos
//     archivos se escriben en disco al arrancar (backend_android.dart).
//   - internal/bundled_extensions/ → la embebida (//go:embed) y la fuente de
//     verdad en runtime: SincronizarConDisco la copia a disco (Android y
//     escritorio) cuando su versión es más nueva que la instalada.
//
// Si divergen, cada plataforma ejecuta una versión distinta de la misma
// extensión. Ya pasó: soundcloud tenía el escaneo de client_id optimizado
// (dedupe de llamadas paralelas + escanear todos los bundles) solo en la copia
// embebida, y spotify-web declaraba una versión distinta en cada copia. Este
// test obliga a que cualquier cambio de extensión se aplique a las dos.
//
// Se conecta con: bundled.go (FS / List) y assets/extensions en disco.
// Parte del flujo: empaquetado de extensiones (paridad assets ↔ embed).
package bundled_extensions

import (
	"bytes"
	"io/fs"
	"os"
	"path/filepath"
	"testing"
)

// TestAssetsYBundledNoDivergen compara archivo por archivo la copia embebida
// con assets/extensions y falla si falta o difiere alguno (en cualquiera de las
// dos direcciones). Se saltea si el repo no tiene assets/extensions a mano.
func TestAssetsYBundledNoDivergen(t *testing.T) {
	// El test corre con CWD = este paquete, así que el repo queda 3 niveles
	// arriba (go_backend/internal/bundled_extensions → raíz).
	raizAssets := filepath.Join("..", "..", "..", "assets", "extensions")
	if _, err := os.Stat(raizAssets); err != nil {
		t.Skipf("assets/extensions no disponible (¿checkout parcial?): %v", err)
	}

	dirs, err := List()
	if err != nil || len(dirs) == 0 {
		t.Fatalf("no hay extensiones empaquetadas: %v", err)
	}

	for _, id := range dirs {
		embebidos := archivosEmbebidos(t, id)
		enAssets := archivosEnDisco(t, filepath.Join(raizAssets, id))

		for rel, data := range embebidos {
			otro, ok := enAssets[rel]
			if !ok {
				t.Errorf("%s/%s: está en la copia embebida pero falta en assets/extensions", id, rel)
				continue
			}
			if !bytes.Equal(data, otro) {
				t.Errorf("%s/%s: assets/extensions y la copia embebida difieren", id, rel)
			}
		}
		for rel := range enAssets {
			if _, ok := embebidos[rel]; !ok {
				t.Errorf("%s/%s: está en assets/extensions pero falta en la copia embebida", id, rel)
			}
		}
	}
}

// archivosEmbebidos devuelve los archivos de [id] en el FS embebido, indexados
// por su ruta relativa a la carpeta de la extensión.
func archivosEmbebidos(t *testing.T, id string) map[string][]byte {
	t.Helper()
	out := map[string][]byte{}
	err := fs.WalkDir(FS, id, func(ruta string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		data, err := fs.ReadFile(FS, ruta)
		if err != nil {
			return err
		}
		rel := ruta[len(id)+1:]
		out[rel] = data
		return nil
	})
	if err != nil {
		t.Fatalf("%s: no se pudo recorrer el FS embebido: %v", id, err)
	}
	return out
}

// archivosEnDisco devuelve los archivos de [raiz], indexados por su ruta
// relativa con separadores "/" (misma forma que el FS embebido).
func archivosEnDisco(t *testing.T, raiz string) map[string][]byte {
	t.Helper()
	out := map[string][]byte{}
	err := filepath.WalkDir(raiz, func(ruta string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(raiz, ruta)
		if err != nil {
			return nil
		}
		data, err := os.ReadFile(ruta)
		if err != nil {
			return nil
		}
		out[filepath.ToSlash(rel)] = data
		return nil
	})
	if err != nil {
		t.Fatalf("%s: no se pudo recorrer el directorio: %v", raiz, err)
	}
	return out
}
