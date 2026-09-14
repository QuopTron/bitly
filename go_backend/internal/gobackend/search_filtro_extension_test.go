package gobackend

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
)

// conManifiestos instala manifiestos de prueba y los restaura al terminar: la
// traducción de categoría → filtro lee de bundledExts, la MISMA tabla que usa
// el backend en runtime.
func conManifiestos(t *testing.T, exts ...bundled_extensions.RegisteredExtension) {
	t.Helper()
	previo := bundledExts
	bundledExts = exts
	t.Cleanup(func() { bundledExts = previo })
}

func filtros(ids ...string) bundled_extensions.Search {
	f := make([]bundled_extensions.SearchFilter, 0, len(ids))
	for _, id := range ids {
		f = append(f, bundled_extensions.SearchFilter{ID: id})
	}
	return bundled_extensions.Search{Filters: f}
}

func TestCategoriaCanonicaDe(t *testing.T) {
	casos := map[string]string{
		"track": "tracks", "tracks": "tracks", "song": "tracks", "songs": "tracks",
		"album": "albums", "albums": "albums",
		"artist": "artists", "artists": "artists",
		"playlist": "playlists", "playlists": "playlists",
		"TRACKS": "tracks", " tracks ": "tracks",
		"all": "", "": "", "videos": "",
	}
	for entrada, quiero := range casos {
		if got := categoriaCanonicaDe(entrada); got != quiero {
			t.Errorf("categoriaCanonicaDe(%q) = %q, quiero %q", entrada, got, quiero)
		}
	}
}

func TestFiltroParaExtensionTraduceElCanonico(t *testing.T) {
	conManifiestos(t,
		bundled_extensions.RegisteredExtension{
			ID: "deezer", Search: filtros("track", "album", "artist", "playlist"),
		},
		bundled_extensions.RegisteredExtension{
			ID: "ytmusic-spotiflac", Search: filtros("tracks", "albums"),
		},
	)

	casos := []struct{ fuente, pedido, quiero string }{
		// El bug: la UI manda el canónico plural y Deezer declara el singular.
		{"deezer", "tracks", "track"},
		{"deezer", "albums", "album"},
		{"deezer", "artists", "artist"},
		{"deezer", "playlists", "playlist"},
		// Idempotente: si ya viene el id del manifest, no se toca.
		{"deezer", "track", "track"},
		// Una extensión que usa plurales se queda con su plural.
		{"ytmusic-spotiflac", "tracks", "tracks"},
		// Categoría que la extensión NO declara: no se inventa un id, se deja
		// el pedido original (la extensión decide qué hacer).
		{"ytmusic-spotiflac", "playlists", "playlists"},
		// Fuente fuera de la tabla (sin searchBehavior): sin traducción.
		{"pandora", "tracks", "tracks"},
	}
	for _, c := range casos {
		if got := filtroParaExtension(c.fuente, c.pedido); got != c.quiero {
			t.Errorf("filtroParaExtension(%q, %q) = %q, quiero %q",
				c.fuente, c.pedido, got, c.quiero)
		}
	}
}

// TestManifiestosRealesTraducenTodasLasCategorias es el test que fija el bug
// contra los manifests que se envían de verdad: recorre assets/extensions y
// comprueba que el id canónico que manda la UI ("tracks") NO llega nunca tal
// cual a una extensión que declara otro id — que es exactamente lo que hacía
// que "Todas" volviera vacía.
func TestManifiestosRealesTraducenTodasLasCategorias(t *testing.T) {
	dir := filepath.Join("..", "..", "..", "assets", "extensions")
	entradas, err := os.ReadDir(dir)
	if err != nil {
		t.Skipf("no se pudieron leer los manifests: %v", err)
	}

	var manifiestos []bundled_extensions.RegisteredExtension
	for _, e := range entradas {
		if !e.IsDir() {
			continue
		}
		crudo, err := os.ReadFile(filepath.Join(dir, e.Name(), "manifest.json"))
		if err != nil {
			continue
		}
		var m struct {
			SearchBehavior bundled_extensions.Search `json:"searchBehavior"`
		}
		if err := json.Unmarshal(crudo, &m); err != nil {
			t.Fatalf("%s: manifest ilegible: %v", e.Name(), err)
		}
		if len(m.SearchBehavior.Filters) == 0 {
			continue
		}
		manifiestos = append(manifiestos, bundled_extensions.RegisteredExtension{
			ID: e.Name(), Search: m.SearchBehavior,
		})
	}
	if len(manifiestos) == 0 {
		t.Fatal("no se encontró ningún manifest con searchBehavior.filters")
	}
	conManifiestos(t, manifiestos...)

	canonicas := []string{"tracks", "albums", "artists", "playlists"}
	for _, m := range manifiestos {
		// Todo id de filtro del manifest tiene que ser reconocible como
		// categoría; si no, la agrupación de resultados no sabría dónde va.
		for _, f := range m.Search.Filters {
			if categoriaCanonicaDe(f.ID) == "" {
				t.Errorf("%s: el filtro %q no corresponde a ninguna categoría",
					m.ID, f.ID)
			}
		}
		for _, canonica := range canonicas {
			declara := false
			for _, f := range m.Search.Filters {
				if categoriaCanonicaDe(f.ID) == canonica {
					declara = true
				}
			}
			if !declara {
				continue
			}
			got := filtroParaExtension(m.ID, canonica)
			// El id resultante TIENE que estar entre los declarados: si no,
			// la extensión devuelve vacío sin error.
			valido := false
			for _, f := range m.Search.Filters {
				if f.ID == got {
					valido = true
				}
			}
			if !valido {
				t.Errorf("%s: para %q se mandaría %q, que la extensión no declara",
					m.ID, canonica, got)
			}
		}
	}
}
