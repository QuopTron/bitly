// Test del arranque empaquetado: LoadAllToRegistry debe registrar las nueve
// extensiones sin compilar ninguna, y compilarlas solas en el primer uso.
//
// La primera parte es el ahorro (el arranque no paga goja); la segunda es la
// garantía de que no rompimos nada: una extensión real tiene que quedar usable.
package bundled_extensions

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

func TestLoadAllRegistraSinCompilarYCompilaAlUsar(t *testing.T) {
	reg := extensions.NewRegistryBestEffort(t.TempDir())

	lista := LoadAllToRegistry(reg)
	if len(lista) == 0 {
		t.Fatal("LoadAllToRegistry no registró ninguna extensión")
	}

	// 1. Nada compilado todavía: el arranque no paga el JS de ninguna.
	for _, ext := range lista {
		sb := reg.Runtime().Sandbox(ext.ID)
		if sb == nil {
			t.Fatalf("%s: debería estar registrada", ext.ID)
		}
		if sb.IsLoaded() {
			t.Errorf("%s: quedó compilada al registrar, que es justo el costo que se sacó del arranque", ext.ID)
		}
		if !reg.Runtime().IsDeferred(ext.ID) {
			t.Errorf("%s: debería figurar como diferida", ext.ID)
		}
	}
	// El registro las cuenta todas: para el llamador "hay extensiones cargadas"
	// es la misma pregunta.
	if got := reg.Runtime().Count(); got != len(lista) {
		t.Errorf("Count() = %d, se esperaba %d", got, len(lista))
	}

	// 2. Una extensión real tiene que compilar al pedirle un método suyo y
	//    quedar usable (sin salir a la red: solo se comprueba que exporta).
	//    customSearch es la búsqueda de ytmusic-spotiflac; searchTracks solo la
	//    implementan algunas fuentes, así que no sirve como control.
	if !reg.Runtime().HasMethod("ytmusic-spotiflac", "customSearch") {
		t.Fatal("ytmusic-spotiflac debería exportar customSearch tras compilarse bajo demanda")
	}
	if reg.Runtime().IsDeferred("ytmusic-spotiflac") {
		t.Error("ya no debería figurar como diferida después del primer uso")
	}
	if !reg.Runtime().Sandbox("ytmusic-spotiflac").IsLoaded() {
		t.Error("el sandbox debería quedar compilado")
	}
	// Una vez compilada sigue respondiendo: no se recompila ni se pierde.
	if !reg.Runtime().HasMethod("ytmusic-spotiflac", "getHomeFeed") {
		t.Error("una extensión ya compilada debería seguir exportando sus métodos")
	}
	// Y compilar una no arrastra a las demás: ese aislamiento es el ahorro.
	if !reg.Runtime().IsDeferred("pandora") {
		t.Error("compilar una extensión no debería arrastrar a las demás")
	}
}

// La capacidad de letras se lee del manifest, así que el wiring no necesita
// ejecutar el JS de ninguna extensión. Sin esto, preguntar por fetchLyrics
// compilaba las nueve (ocho para descartarlas).
func TestCapacidadDeLetrasVieneDelManifest(t *testing.T) {
	reg := extensions.NewRegistryBestEffort(t.TempDir())
	lista := LoadAllToRegistry(reg)

	porID := map[string]RegisteredExtension{}
	for _, ext := range lista {
		porID[ext.ID] = ext
	}

	// apple-music declara lyrics_provider y su JS exporta fetchLyrics.
	apple, ok := porID["apple-music"]
	if !ok {
		t.Fatal("apple-music debería estar en la lista")
	}
	if !apple.HasLyricsProvider {
		t.Error("apple-music declara lyrics_provider en su manifest")
	}
	// El resto NO lo declara: esa es la respuesta que evita el sondeo.
	for id, ext := range porID {
		if id == "apple-music" {
			continue
		}
		if ext.HasLyricsProvider {
			t.Errorf("%s no declara lyrics_provider; al sondearlo se compilaría entera", id)
		}
	}

	// Y ninguna quedó compilada por haber consultado la capacidad.
	for _, ext := range lista {
		if reg.Runtime().Sandbox(ext.ID).IsLoaded() {
			t.Errorf("%s: consultar capacidades no debería compilar nada", ext.ID)
		}
	}
}
