// sin_zarz_test.go — Guard contra el regreso de zarz y del modal de humano.
//
// Por qué existe: el modal de Cloudflare/Turnstile NO venía de descargar, venía
// del arranque. Cualquier extensión que declare `signedSession` en su manifest
// hace que la app pida provisionar esa sesión contra api.zarz.moe; ese
// bootstrap responde VERIFY_REQUIRED y abre el modal. Y cualquier manifest con
// `api.zarz.moe` en sus permisos declara una dependencia que ya no queremos.
//
// Si alguien reintroduce cualquiera de las dos cosas, este test falla y explica
// que el modal volvería.
//
// Se conecta con: bundled.go (FS / List).
// Parte del flujo: empaquetado de extensiones (sin dependencias externas).
package bundled_extensions

import (
	"io/fs"
	"strings"
	"testing"
)

// TestNingunaExtensionDeclaraZarzNiSesionFirmada recorre los manifests
// embebidos y falla si alguno reintroduce la dependencia del gateway.
func TestNingunaExtensionDeclaraZarzNiSesionFirmada(t *testing.T) {
	dirs, err := List()
	if err != nil || len(dirs) == 0 {
		t.Fatalf("no hay extensiones empaquetadas: %v", err)
	}

	for _, id := range dirs {
		manifest, err := fs.ReadFile(FS, id+"/manifest.json")
		if err != nil {
			t.Fatalf("%s: no se pudo leer el manifest: %v", id, err)
		}
		texto := string(manifest)

		if strings.Contains(texto, "api.zarz.moe") {
			t.Errorf("%s/manifest.json declara el permiso api.zarz.moe: "+
				"quita la dependencia de zarz", id)
		}
		if strings.Contains(texto, "signedSession") {
			t.Errorf("%s/manifest.json declara signedSession: "+
				"eso vuelve a pedir el bootstrap del gateway y abre el "+
				"modal de verificación al arrancar", id)
		}
	}
}
