// deezer_qobuz_conformidad_test.go — Conformidad de los ítems de deezer y
// qobuz-web en TODAS las vistas.
//
// Cómo: se corre el `formatTrack` REAL de cada extensión (el mismo que usan
// búsqueda, feed y detalle) con un fixture de la forma cruda que devuelve su
// API. Es la función pura, así que no hace falta red ni fixtures de páginas.
//
// Qué fija: (1) los campos de identidad que el matching necesita —name,
// artists, album_name, duration_ms, isrc, provider_id, item_type— y (2) que el
// marcador de versión (Remix) NO se pierda, porque un remix sin marcador pasa
// como original y se sirve la grabación equivocada.
package bundled_extensions

import (
	"strings"
	"testing"
)

func TestDeezerFormatTrackEmiteIdentidadYVersion(t *testing.T) {
	guion := `
function dump(t, etiqueta) {
  var out = formatTrack(t, {});
  console.log(etiqueta + "-name=" + out.name);
  console.log(etiqueta + "-artists=" + out.artists);
  console.log(etiqueta + "-album=" + out.album_name);
  console.log(etiqueta + "-duration=" + out.duration_ms);
  console.log(etiqueta + "-isrc=" + out.isrc);
  console.log(etiqueta + "-provider=" + out.provider_id);
  console.log(etiqueta + "-type=" + out.item_type);
}
dump({
  id: 4208859922, title: "BbY WOW", duration: 225, isrc: "USUG12607940",
  artist: { id: 1234, name: "KAROL G" },
  album: { id: 99, title: "NO ME ARREPIENTO DE SENTIR TANTO", artist: { id: 1234, name: "KAROL G" } }
}, "real");
dump({ id: 5, title: "BbY WOW (Remix)", duration: 180, isrc: "XXAAA2600001",
  artist: { id: 1, name: "Otro" }, album: { id: 7, title: "Remixes" } }, "remix");
`
	salida := ejecutarLogicaExtension(t, "deezer", guion)
	exigir(t, salida, "real-name=BbY WOW")
	exigir(t, salida, "real-artists=KAROL G")
	exigir(t, salida, "real-album=NO ME ARREPIENTO DE SENTIR TANTO")
	exigir(t, salida, "real-duration=225000")
	exigir(t, salida, "real-isrc=USUG12607940")
	exigir(t, salida, "real-provider=deezer")
	exigir(t, salida, "real-type=track")
	// El marcador de versión sobrevive al formateo.
	exigir(t, salida, "remix-name=BbY WOW (Remix)")
}

func TestQobuzFormatTrackEmiteIdentidadYVersion(t *testing.T) {
	guion := `
function dump(t, etiqueta) {
  var out = formatTrack(t, null, {});
  console.log(etiqueta + "-name=" + out.name);
  console.log(etiqueta + "-artists=" + out.artists);
  console.log(etiqueta + "-album=" + out.album_name);
  console.log(etiqueta + "-duration=" + out.duration_ms);
  console.log(etiqueta + "-isrc=" + out.isrc);
  console.log(etiqueta + "-provider=" + out.provider_id);
  console.log(etiqueta + "-type=" + out.item_type);
}
dump({
  id: 312055179, title: "BbY WOW", version: "", duration: 225, isrc: "USUG12607940",
  performer: { id: 1, name: "KAROL G" },
  album: { id: 9, title: "NO ME ARREPIENTO DE SENTIR TANTO",
    artist: { id: 1, name: "KAROL G" }, artists: [{ id: 1, name: "KAROL G" }],
    tracks_count: 1, media_count: 1, image: { large: "https://x/c.jpg" } }
}, "real");
dump({ id: 8, title: "BbY WOW", version: "Remix", duration: 180, isrc: "XXAAA2600002",
  performer: { id: 2, name: "Otro" },
  album: { id: 7, title: "Remixes", artist: { id: 2, name: "Otro" }, artists: [{ id: 2, name: "Otro" }], tracks_count: 1, media_count: 1 } }, "remix");
`
	salida := ejecutarLogicaExtension(t, "qobuz-web", guion)
	exigir(t, salida, "real-name=BbY WOW")
	exigir(t, salida, "real-artists=KAROL G")
	exigir(t, salida, "real-album=NO ME ARREPIENTO DE SENTIR TANTO")
	exigir(t, salida, "real-duration=225000")
	exigir(t, salida, "real-isrc=USUG12607940")
	exigir(t, salida, "real-provider=qobuz-web")
	exigir(t, salida, "real-type=track")
	// La versión de Qobuz vive en `version`, no en `title`: tiene que aparecer.
	exigir(t, salida, "remix-name=BbY WOW (Remix)")
}

func exigir(t *testing.T, salida, marcador string) {
	t.Helper()
	if !strings.Contains(salida, marcador) {
		t.Errorf("falta %q en la salida:\n%s", marcador, salida)
	}
}
