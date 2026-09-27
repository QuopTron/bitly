// ─────────────────────────────────────────────────────────────
// homefeed_coherencia_test.go — El flag del manifest y el código tienen que
// decir lo MISMO.
//
// Por qué existe: `capabilities.homeFeed` es lo que decide si el backend
// intenta el feed de una fuente (HomeFeedEnabled). Si dice true y la extensión
// no exporta getHomeFeed(), el backend le paga una llamada y un timeout por
// cada apertura del feed para recibir nada; si dice false y SÍ lo implementa,
// el feed queda invisible (el caso de apple-music y soundcloud antes de este
// cambio). Las dos cosas se ven como "esa fuente no tiene feed".
//
// Se comprueba SRC contra el texto de la extensión: es un archivo JSON + JS
// empaquetado, así que no hay ejecución de por medio y el test no sale a
// Internet.
// ─────────────────────────────────────────────────────────────

package bundled_extensions

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHomeFeedDeclaradoEImplementado(t *testing.T) {
	raiz := "."
	entradas, err := os.ReadDir(raiz)
	if err != nil {
		t.Fatalf("no se pudo leer el directorio de extensiones: %v", err)
	}

	declaradas := 0
	for _, entrada := range entradas {
		if !entrada.IsDir() {
			continue
		}
		id := entrada.Name()
		manifestPath := filepath.Join(raiz, id, "manifest.json")
		indexPath := filepath.Join(raiz, id, "index.js")

		crudo, err := os.ReadFile(manifestPath)
		if err != nil {
			continue // no es una extensión (no hay manifest)
		}
		var manifest struct {
			Capabilities struct {
				HomeFeed bool `json:"homeFeed"`
			} `json:"capabilities"`
		}
		if err := json.Unmarshal(crudo, &manifest); err != nil {
			t.Errorf("%s: manifest ilegible: %v", id, err)
			continue
		}

		index, err := os.ReadFile(indexPath)
		if err != nil {
			t.Errorf("%s: falta index.js", id)
			continue
		}
		codigo := string(index)
		// Implementado = la función existe Y está registrada para el runtime, que
		// es lo que realmente la expone (registerExtension({ getHomeFeed: ... })).
		implementado := strings.Contains(codigo, "function getHomeFeed") &&
			strings.Contains(codigo, "getHomeFeed:")

		switch {
		case manifest.Capabilities.HomeFeed && !implementado:
			t.Errorf("%s: declara capabilities.homeFeed=true pero no implementa/registra getHomeFeed()", id)
		case !manifest.Capabilities.HomeFeed && implementado:
			t.Errorf("%s: implementa getHomeFeed() pero el manifest no lo declara (capabilities.homeFeed=false)", id)
		}
		if manifest.Capabilities.HomeFeed {
			declaradas++
		}
	}

	// Las cuatro que este cambio sumó: si alguna pierde el flag, el feed deja de
	// existir sin que nada falle.
	for _, id := range []string{"deezer", "qobuz-web", "tidal-web", "soundcloud"} {
		crudo, err := os.ReadFile(filepath.Join(raiz, id, "manifest.json"))
		if err != nil {
			t.Fatalf("%s: %v", id, err)
		}
		if !strings.Contains(string(crudo), `"homeFeed": true`) {
			t.Errorf("%s: debería declarar capabilities.homeFeed=true", id)
		}
	}
	if declaradas < 4 {
		t.Errorf("solo %d extensiones declaran feed; se esperaban al menos 4", declaradas)
	}
}
