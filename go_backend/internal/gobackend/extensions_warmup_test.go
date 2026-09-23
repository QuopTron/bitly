// Tests del precalentamiento: las extensiones diferidas se compilan solas en
// segundo plano, así el primer uso del usuario no paga la compilación.
package gobackend

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
)

// El orden importa: lo que el usuario toca al abrir (la fuente primaria de
// búsqueda y las que traen feed) tiene que compilarse primero. Si el warm-up
// compilara en orden alfabético, ytmusic-spotiflac —la última— sería la última
// en estar lista, justo la que más se usa.
func TestOrdenDePrecalentamientoPriorizaLoQueSeUsaPrimero(t *testing.T) {
	exts := []bundled_extensions.RegisteredExtension{
		{ID: "pandora"},
		{ID: "ytmusic-spotiflac", HasHomeFeed: true},
		{ID: "deezer", Search: bundled_extensions.Search{Primary: true}, HasHomeFeed: true},
		{ID: "amazon", HasHomeFeed: true},
		{ID: "qobuz-web"},
	}

	orden := ordenDePrecalentamiento(exts)

	if len(orden) != len(exts) {
		t.Fatalf("el orden debe incluir todas las extensiones: %v", orden)
	}
	if orden[0] != "deezer" {
		t.Errorf("la fuente primaria debe ir primera, no %q (%v)", orden[0], orden)
	}
	// Las que traen feed van antes que las que no, y todas aparecen una sola vez.
	vistos := map[string]int{}
	for _, id := range orden {
		vistos[id]++
	}
	for id, n := range vistos {
		if n != 1 {
			t.Errorf("%s aparece %d veces en el orden", id, n)
		}
	}
	sinFeed := map[string]bool{"pandora": true, "qobuz-web": true}
	ultimas := orden[len(orden)-2:]
	for _, id := range ultimas {
		if !sinFeed[id] {
			t.Errorf("las que no traen feed deben ir al final (%v)", orden)
		}
	}
}

// El precalentamiento tiene que dejar de verdad las extensiones compiladas: si
// se rompiera, el ahorro del arranque se pagaría con una compilación en el hilo
// del primer uso del usuario (justo lo que el warm-up evita).
func TestPrecalentamientoCompilaLoDiferido(t *testing.T) {
	prepararBinariosArranque(t)
	silenciarLogArranque(t)

	if InitGlobalState() == "" {
		t.Fatal("el arranque no devolvió respuesta")
	}
	er := getExtRegistry()
	if er == nil {
		t.Fatal("no hay registro de extensiones")
	}
	if len(bundledExts) == 0 {
		t.Fatal("el arranque no registró extensiones empaquetadas")
	}
	// Punto de partida: nada compilado, que es el ahorro del arranque.
	for _, ext := range bundledExts {
		if er.Runtime().Sandbox(ext.ID).IsLoaded() {
			t.Fatalf("%s quedó compilada durante el arranque", ext.ID)
		}
	}

	// Espera 0 para no alargar el test; en producción son 2s.
	precalentarExtensiones(bundledExts, 0)

	limite := time.Now().Add(30 * time.Second)
	for time.Now().Before(limite) {
		diferidas := 0
		for _, ext := range bundledExts {
			if er.Runtime().IsDeferred(ext.ID) {
				diferidas++
			}
		}
		if diferidas == 0 {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	for _, ext := range bundledExts {
		if er.Runtime().IsDeferred(ext.ID) {
			t.Errorf("%s: el precalentamiento no la compiló", ext.ID)
		}
		if !er.Runtime().Sandbox(ext.ID).IsLoaded() {
			t.Errorf("%s: quedó diferida pero sin VM compilada", ext.ID)
		}
	}
}
