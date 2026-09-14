package gobackend

import (
	"encoding/json"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/deezer"
	"github.com/zarz/bitly/go_backend/internal/provider/internetarchive"
	"github.com/zarz/bitly/go_backend/internal/provider/soulseek"
)

// EL CONTRATO QUE ESTE TEST FIJA
// Los proveedores de respaldo (Internet Archive, Soulseek, flac-rescue,
// redacted, musicbrainz) NO pueden ofrecerse ni evaluarse como fuente de
// búsqueda: no son catálogos navegables. Buscar mostraba sus resultados como
// si fueran de una extensión más, y el usuario no tenía forma de saber que ese
// no era un catálogo. Siguen registrados —el rescate lossless los necesita—
// así que la única garantía es que el filtro se aplique en TODOS los caminos
// de búsqueda: la lista de fuentes, la config de búsqueda y el walk
// multi-proveedor.

func TestEsFuenteDeBusqueda(t *testing.T) {
	respaldo := []string{
		"internetarchive", "soulseek", "flac-rescue", "redacted", "musicbrainz",
		" InternetArchive ", "SOULSEEK",
	}
	for _, id := range respaldo {
		if esFuenteDeBusqueda(id) {
			t.Errorf("esFuenteDeBusqueda(%q) = true; no debe ofrecerse como fuente", id)
		}
	}
	catalogos := []string{
		"deezer", "apple-music", "soundcloud", "spotify-web", "qobuz-web",
		"tidal-web", "ytmusic-spotiflac", "amazon", "",
	}
	for _, id := range catalogos {
		if !esFuenteDeBusqueda(id) {
			t.Errorf("esFuenteDeBusqueda(%q) = false; es una fuente legítima", id)
		}
	}
}

// TestGetSourcesOcultaRespaldo comprueba el RPC que la UI usa para armar el
// selector: Internet Archive y Soulseek no deben aparecer, Deezer sí.
func TestGetSourcesOcultaRespaldo(t *testing.T) {
	previo := reg
	reg = provider.NewRegistry()
	t.Cleanup(func() { reg = previo })

	reg.Register(deezer.NewClient(nil))
	reg.Register(internetarchive.NewClient(nil))
	reg.Register(soulseek.NewClient("", ""))

	var fuentes []string
	if err := json.Unmarshal([]byte(GetSources()), &fuentes); err != nil {
		t.Fatalf("GetSources() no devolvió JSON válido: %v", err)
	}
	vistas := map[string]bool{}
	for _, f := range fuentes {
		vistas[f] = true
	}
	if !vistas["deezer"] {
		t.Errorf("Deezer debería estar en las fuentes: %v", fuentes)
	}
	if vistas["internetarchive"] || vistas["soulseek"] {
		t.Errorf("los proveedores de respaldo no deben listarse como fuentes: %v", fuentes)
	}
}

// TestProvidersBusquedaOrdenadosExcluyeRespaldo fija el walk multi-proveedor
// (el que corre cuando una búsqueda llega sin fuente): si no filtrara, un
// "todas las fuentes" volvería a mezclar resultados de Internet Archive.
func TestProvidersBusquedaOrdenadosExcluyeRespaldo(t *testing.T) {
	previo := reg
	reg = provider.NewRegistry()
	t.Cleanup(func() { reg = previo })

	reg.Register(deezer.NewClient(nil))
	reg.Register(internetarchive.NewClient(nil))
	reg.Register(soulseek.NewClient("", ""))

	for _, p := range providersBusquedaOrdenados() {
		if !esFuenteDeBusqueda(p.Name()) {
			t.Errorf("providersBusquedaOrdenados incluyó %q, que es solo respaldo", p.Name())
		}
	}
	// Y el catálogo real sigue entrando: si el filtro borrara todo, el test de
	// arriba pasaría por vacío.
	var hayCatalogo bool
	for _, p := range providersBusquedaOrdenados() {
		if p.Name() == "deezer" {
			hayCatalogo = true
		}
	}
	if !hayCatalogo {
		t.Error("providersBusquedaOrdenados se quedó sin catálogos: filtró de más")
	}
}

// TestGetSearchConfigOcultaRespaldo: aunque una extensión de respaldo declare
// searchBehavior con filtros, no puede aparecer en la config de búsqueda (de
// ahí salen las burbujas de categoría y el selector de la UI).
func TestGetSearchConfigOcultaRespaldo(t *testing.T) {
	conManifiestos(t,
		bundled_extensions.RegisteredExtension{
			ID:     "deezer",
			Search: filtros("track", "album", "artist", "playlist"),
		},
		bundled_extensions.RegisteredExtension{
			ID:     "internetarchive",
			Search: filtros("tracks"),
		},
	)

	var cfg []SourceSearchConfig
	if err := json.Unmarshal([]byte(GetSearchConfig()), &cfg); err != nil {
		t.Fatalf("GetSearchConfig() no devolvió JSON válido: %v", err)
	}
	for _, c := range cfg {
		if c.Source == "internetarchive" {
			t.Error("internetarchive no debe estar en la config de búsqueda")
		}
	}
	if len(cfg) != 1 || cfg[0].Source != "deezer" {
		t.Errorf("config de búsqueda = %+v, quería solo deezer", cfg)
	}
}
