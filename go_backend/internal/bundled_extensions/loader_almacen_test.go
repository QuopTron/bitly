// Test del directorio de almacén de las extensiones empaquetadas.
//
// El host publica la carpeta escribible en BITLY_DATA_DIR antes de registrar
// extensiones (SetAppDataDir en el arranque nativo). Antes se registraban con
// "." y su Store terminaba escribiendo en el directorio de trabajo del proceso
// — en Android "/", no escribible — así que todo lo que persistían se perdía en
// silencio.
//
// Este test fija que la ruta real se use desde el nacimiento del sandbox, no
// recién cuando el host la confirma por segunda vez.
package bundled_extensions

import (
	"path/filepath"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

func TestExtensionesEmpaquetadasNacenConElDataDirReal(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("BITLY_DATA_DIR", dir)

	reg := extensions.NewRegistryBestEffort(t.TempDir())
	lista := LoadAllToRegistry(reg)
	if len(lista) == 0 {
		t.Fatal("LoadAllToRegistry no registró ninguna extensión")
	}

	for _, ext := range lista {
		sb := reg.Runtime().Sandbox(ext.ID)
		if sb == nil {
			t.Fatalf("%s: debería estar registrada", ext.ID)
		}
		if sb.DataDir != dir {
			t.Errorf("%s: DataDir = %q, se esperaba %q", ext.ID, sb.DataDir, dir)
		}
		if sb.Store == nil {
			t.Errorf("%s: debería tener Store desde el registro", ext.ID)
			continue
		}
		if got := filepath.Dir(sb.Store.FilePath()); got != dir {
			t.Errorf(
				"%s: el almacén quedó en %q, se esperaba %q (persistiría fuera de la carpeta de la app)",
				ext.ID, got, dir,
			)
		}
	}
}

// Sin BITLY_DATA_DIR configurado se cae a "." (tests, escritorio sin data dir):
// el fallback tiene que seguir existiendo para no romper esos entornos.
func TestSinDataDirConfiguradoCaeAPunto(t *testing.T) {
	t.Setenv("BITLY_DATA_DIR", "")

	reg := extensions.NewRegistryBestEffort(t.TempDir())
	lista := LoadAllToRegistry(reg)
	if len(lista) == 0 {
		t.Fatal("LoadAllToRegistry no registró ninguna extensión")
	}

	sb := reg.Runtime().Sandbox(lista[0].ID)
	if sb == nil {
		t.Fatalf("%s: debería estar registrada", lista[0].ID)
	}
	if sb.DataDir != "." {
		t.Errorf("DataDir = %q, se esperaba el fallback \".\"", sb.DataDir)
	}
}
