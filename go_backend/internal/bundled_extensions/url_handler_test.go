// url_handler_test.go — Guard de la resolución de enlaces compartidos.
//
// Por qué existe: las extensiones implementan handleUrl(url) y declaran en su
// manifest qué hosts saben resolver (urlHandler.patterns). Pero el loader NO
// leía ese bloque, así que ningún enlace de Spotify/YouTube podía enrutarse a
// su extensión: compartir un enlace no hacía nada.
//
// Este test falla si el loader deja de propagar los patrones (o si un manifest
// pierde su urlHandler), que es justo la regresión que deja los enlaces rotos.
//
// Se conecta con: bundled.go (FS) + loader_all.go (LoadAllToRegistry).
// Parte del flujo: empaquetado de extensiones → resolución de enlaces.
package bundled_extensions

import (
	"encoding/json"
	"io/fs"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

func TestLoaderPropagaPatronesDeUrlHandler(t *testing.T) {
	reg := extensions.NewRegistryBestEffort(t.TempDir())
	lista := LoadAllToRegistry(reg)
	if len(lista) == 0 {
		t.Fatal("no se cargó ninguna extensión empaquetada")
	}

	conPatrones := 0
	for _, ext := range lista {
		manifest, err := fs.ReadFile(FS, ext.ID+"/manifest.json")
		if err != nil {
			t.Fatalf("%s: no se pudo leer el manifest: %v", ext.ID, err)
		}
		// Se decodifica sólo lo que este test verifica; si el loader dejara de
		// leer urlHandler, Patterns quedaría vacío y la comparación falla.
		var crudo struct {
			URLHandler struct {
				Patterns []string `json:"patterns"`
			} `json:"urlHandler"`
		}
		if err := json.Unmarshal(manifest, &crudo); err != nil {
			t.Fatalf("%s: manifest inválido: %v", ext.ID, err)
		}

		quiere := crudo.URLHandler.Patterns
		got := ext.URLHandler.Patterns
		if len(quiere) != len(got) {
			t.Errorf("%s: el loader expone %d patrones, el manifest declara %d (%v vs %v)",
				ext.ID, len(got), len(quiere), got, quiere)
			continue
		}
		for i := range quiere {
			if quiere[i] != got[i] {
				t.Errorf("%s: patrón %d = %q, quiero %q", ext.ID, i, got[i], quiere[i])
			}
		}
		if len(got) > 0 {
			conPatrones++
		}
	}

	// Las fuentes que el usuario comparte a diario tienen que estar cubiertas.
	if conPatrones < 5 {
		t.Errorf("sólo %d extensiones declararon urlHandler; se esperaban al menos 5", conPatrones)
	}
	if patrones := patronesDe(t, lista, "spotify-web"); !contiene(patrones, "open.spotify.com") {
		t.Errorf("spotify-web no declara open.spotify.com: %v", patrones)
	}
	if patrones := patronesDe(t, lista, "ytmusic-spotiflac"); !contiene(patrones, "youtu.be") {
		t.Errorf("ytmusic-spotiflac no declara youtu.be: %v", patrones)
	}
}

func patronesDe(t *testing.T, lista []RegisteredExtension, id string) []string {
	t.Helper()
	for _, ext := range lista {
		if ext.ID == id {
			return ext.URLHandler.Patterns
		}
	}
	t.Fatalf("no se encontró la extensión %s", id)
	return nil
}

func contiene(lista []string, valor string) bool {
	for _, v := range lista {
		if v == valor {
			return true
		}
	}
	return false
}
