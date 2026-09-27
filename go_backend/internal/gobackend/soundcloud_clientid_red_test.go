package gobackend

import (
	"os"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// TestSoundCloudClientIdReal es la prueba CONTRA SOUNDCLOUD REAL del rescate del
// client_id, apagada por defecto.
//
// Por qué existe: el client_id es lo que abre TODA la fuente (búsqueda, feed y
// descarga salen por la misma API) y su obtención depende de cómo SoundCloud
// publique su frontend hoy. Cuando esa extracción se rompe, el síntoma no es un
// error claro sino "SoundCloud no devuelve resultados de a ratos", que es justo
// el fallo que este test tiene que delatar.
//
// No corre en la batería normal ni en los workflows: depende de un tercero y tarda
// unos segundos. Un SoundCloud caído deja el test fallando a propósito (un id que
// ya no se puede obtener ES el problema que vigila).
//
// Run:
//
//	cd go_backend && BITLY_SC_RED=1 go test ./internal/gobackend -run TestSoundCloudClientIdReal -count=1 -v
func TestSoundCloudClientIdReal(t *testing.T) {
	if os.Getenv("BITLY_SC_RED") != "1" {
		t.Skip("define BITLY_SC_RED=1 para probar SoundCloud real")
	}
	InitGlobalState()
	InitExtensionSystem(`{"extensions_dir":"","data_dir":""}`)
	LoadExtensionsFromDir(`{"dir_path":""}`)

	p := reg.Get("soundcloud")
	if p == nil {
		t.Fatal("soundcloud no está registrada")
	}

	// La búsqueda es la que fuerza la obtención del client_id.
	res, err := p.SearchTracks("afterparty", 3)
	if err != nil {
		t.Fatalf("la búsqueda falló (¿client_id?): %v", err)
	}
	if len(res) == 0 {
		t.Fatal("la búsqueda no devolvió resultados: la fuente está sin client_id usable")
	}
	for _, r := range res {
		t.Logf("busqueda: %q / %q (%dms)", r.Title, r.Artist, r.Duration)
	}

	ep, ok := p.(*provider.ExtensionProvider)
	if !ok {
		t.Fatal("soundcloud no es ExtensionProvider")
	}
	secciones, err := ep.GetHomeFeed()
	if err != nil {
		t.Fatalf("el feed falló: %v", err)
	}
	if len(secciones) == 0 {
		t.Fatal("el feed no devolvió secciones")
	}
	total := 0
	for _, s := range secciones {
		t.Logf("feed: %q con %d items", s.Title, len(s.Items))
		total += len(s.Items)
	}
	if total == 0 {
		t.Fatal("las secciones del feed vinieron vacías")
	}
}
