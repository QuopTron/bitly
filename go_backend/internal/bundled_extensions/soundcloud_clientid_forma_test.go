// ─────────────────────────────────────────────────────────────
// soundcloud_clientid_forma_test.go — Guarda de FORMA del rescate del
// client_id de SoundCloud.
//
// Por qué una guarda de texto: la lógica vive en JS y este repo no ejecuta JS
// con red falsa (el sandbox no permite sustituir `http.get`), así que la
// comprobación funcional es el test de red `TestSoundCloudClientIdReal`
// (BITLY_SC_RED=1) y esto solo vigila que no se borren las piezas que costó
// medir. La falla que evita es silenciosa: si desaparece la lectura del bloque
// de arranque, la fuente sigue funcionando a veces (cuando le toca una página
// con el patrón viejo) y falla otras, que es exactamente el síntoma reportado.
//
// Si alguna de estas piezas se renombra a propósito, actualizá también esta
// guarda: el valor está en que el borrado sea una decisión, no un descuido.
// ─────────────────────────────────────────────────────────────

package bundled_extensions

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSoundCloudConservaElRescateDelClientId(t *testing.T) {
	crudo, err := os.ReadFile(filepath.Join(".", "soundcloud", "index.js"))
	if err != nil {
		t.Fatalf("no se pudo leer la extensión de SoundCloud: %v", err)
	}
	codigo := string(crudo)

	piezas := []struct {
		nombre string
		marca  string
		porQue string
	}{
		{
			nombre: "lectura del bloque de arranque",
			marca:  "clientIdDesdeHydration",
			porQue: "es el camino de UNA petición (__sc_hydration → apiClient); sin él se vuelve a recorrer bundles y vuelve la intermitencia",
		},
		{
			nombre: "validación del candidato",
			marca:  "verificarClientId",
			porQue: "un id con formato válido pero muerto se guardaba 24h y envenenaba la fuente",
		},
		{
			nombre: "páginas de respaldo",
			marca:  "PAGINAS_CLIENT_ID",
			porQue: "la página principal responde variantes según el frontend; sin respaldo, esa variante deja la fuente muerta",
		},
		{
			nombre: "recorrido de bundles como último recurso",
			marca:  "clientIdDeBundles",
			porQue: "es la red de seguridad cuando ni el bloque de arranque ni el HTML publican el id",
		},
		{
			nombre: "no adoptar el id que acaba de fallar",
			marca:  "esElMismoIdMuerto",
			porQue: "un id idéntico al que dio 401 está muerto: adoptarlo lo cacheaba 24h y gastaba una petición en confirmarlo",
		},
		{
			nombre: "rescate sin reverificar en el camino del 401",
			marca:  "sinVerificar",
			porQue: "ahí el reintento con el id nuevo ES la verificación; comprobar antes duplicaba las peticiones (el verificador soundcloud_401 cuenta exactamente esas)",
		},
		{
			nombre: "invalidar el id que tampoco sirvió",
			marca:  "invalidarClientId",
			porQue: "un id rescatado que falla en el reintento no debe quedar 24h en el storage envenenando los arranques siguientes",
		},
	}
	for _, p := range piezas {
		if !strings.Contains(codigo, p.marca) {
			t.Errorf("falta %s (%s): %s", p.nombre, p.marca, p.porQue)
		}
	}

	// Y el registro tiene que seguir exponiendo el feed y la búsqueda, que son
	// lo que se rompe cuando no hay client_id.
	for _, marca := range []string{"getHomeFeed: getHomeFeed", "searchTracks: searchTracks"} {
		if !strings.Contains(codigo, marca) {
			t.Errorf("la extensión dejó de registrar %q", marca)
		}
	}

	// El camino del 401 tiene que pedir el rescate en modo "sin verificar" y
	// conociendo el id anterior: sin las dos cosas vuelven las peticiones de más
	// (una por verificar el candidato) y el "HTTP 401" que Go usa para el cooldown.
	if !strings.Contains(codigo, "ensureClientId({ idAnterior: idAnterior, sinVerificar: true })") {
		t.Error("el reintento por 401 dejó de rescatar con { idAnterior, sinVerificar }: vuelve a gastar una petición por candidato")
	}
	for _, mensaje := range []string{
		"SoundCloud API failed after retry: HTTP 401 (client_id no renovable)",
	} {
		if strings.Count(codigo, mensaje) < 2 {
			t.Errorf("falta el marcador %q en alguno de los dos cortes por 401 (rescate fallido y mismo id)", mensaje)
		}
	}
}
