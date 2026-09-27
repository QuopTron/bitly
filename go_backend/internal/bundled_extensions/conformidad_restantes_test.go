// conformidad_restantes_test.go — Conformidad de las 7 extensiones restantes
// (amazon, apple-music, tidal-web, spotify-web, ytmusic-spotiflac, soundcloud y
// pandora) en las vistas que cada una construye con un formateador puro.
//
// Cómo: se corre el formateador REAL de cada extensión con un fixture de la
// forma cruda de su API. Sin red. Lo que se fija es lo mismo que en deezer y
// qobuz-web: los campos de identidad que el matching necesita (name, artists,
// album_name, duration_ms, isrc, provider_id) y que el marcador de versión no
// se pierda — un remix sin marcador pasa como original y se sirve la toma
// equivocada.
package bundled_extensions

import "testing"

// campo imprime "<etiqueta>-<campo>=<valor>" para poder exigir substrings.
const ayudaVolcado = `
function volcar(out, etiqueta) {
  console.log(etiqueta + "-name=" + out.name);
  console.log(etiqueta + "-artists=" + out.artists);
  console.log(etiqueta + "-album=" + out.album_name);
  console.log(etiqueta + "-duration=" + out.duration_ms);
  console.log(etiqueta + "-isrc=" + out.isrc);
  console.log(etiqueta + "-provider=" + out.provider_id);
}
`

func TestAmazonFormateadorEmiteIdentidad(t *testing.T) {
	guion := ayudaVolcado + `
volcar(formatAmazonTrackMetadata({
  id: "B0HL1XPQR8", name: "BbY WOW", artists: "KAROL G",
  album_name: "NO ME ARREPIENTO DE SENTIR TANTO", duration_ms: 225000,
  isrc: "USUG12607940"
}, {}, 1), "real");
volcar(formatAmazonTrackMetadata({
  id: "B0X", name: "BbY WOW (Remix)", artists: "KAROL G",
  album_name: "Remixes", duration_ms: 180000, isrc: "XXAAA2600001"
}, {}, 1), "remix");
`
	salida := ejecutarLogicaExtension(t, "amazon", guion)
	exigirCamposBase(t, salida, "real", "amazon")
	exigir(t, salida, "remix-name=BbY WOW (Remix)")
}

func TestAppleMusicFormateadorEmiteIdentidad(t *testing.T) {
	guion := ayudaVolcado + `
var album = { id: "9", attributes: {
  name: "NO ME ARREPIENTO DE SENTIR TANTO", artistName: "KAROL G",
  trackCount: 1, artwork: { url: "https://x/{w}x{h}.jpg" } } };
volcar(formatSong({
  id: "144", attributes: { name: "BbY WOW", artistName: "KAROL G",
    albumName: "NO ME ARREPIENTO DE SENTIR TANTO", durationInMillis: 225000,
    isrc: "USUG12607940", trackNumber: 1, discNumber: 1 }
}, album, 1), "real");
volcar(formatSong({
  id: "145", attributes: { name: "BbY WOW (Remix)", artistName: "KAROL G",
    albumName: "Remixes", durationInMillis: 180000, isrc: "XXAAA2600001",
    trackNumber: 2, discNumber: 1 }
}, album, 1), "remix");
`
	salida := ejecutarLogicaExtension(t, "apple-music", guion)
	exigirCamposBase(t, salida, "real", "apple-music")
	exigir(t, salida, "remix-name=BbY WOW (Remix)")
}

func TestTidalWebFormateadorEmiteIdentidadYVersion(t *testing.T) {
	guion := ayudaVolcado + `
volcar(formatTrack({
  id: 111, title: "BbY WOW", artists: [{ id: 1, name: "KAROL G" }],
  album: { id: 9, title: "NO ME ARREPIENTO DE SENTIR TANTO",
    numberOfTracks: 1, numberOfVolumes: 1 },
  duration: 225, isrc: "USUG12607940"
}, {}), "real");
volcar(formatTrack({
  id: 112, title: "BbY WOW", version: "Remix",
  artists: [{ id: 1, name: "KAROL G" }],
  album: { id: 9, title: "NO ME ARREPIENTO DE SENTIR TANTO",
    numberOfTracks: 1, numberOfVolumes: 1 },
  duration: 180, isrc: "XXAAA2600001"
}, {}), "remix");
`
	salida := ejecutarLogicaExtension(t, "tidal-web", guion)
	exigirCamposBase(t, salida, "real", "tidal-web")
	// La versión de TIDAL vive en `version`: tiene que aparecer en el nombre.
	exigir(t, salida, "remix-name=BbY WOW (Remix)")
}

func TestYtmusicFormateadorEmiteIdentidad(t *testing.T) {
	guion := ayudaVolcado + `
volcar(sanitizeTrackBeforeReturn({
  id: "vid12345678", title: "BbY WOW", artist: "KAROL G",
  album: "NO ME ARREPIENTO DE SENTIR TANTO", duration: 225, isrc: "USUG12607940"
}), "real");
volcar(sanitizeTrackBeforeReturn({
  id: "vid87654321", title: "BbY WOW (Remix)", artist: "KAROL G",
  album: "Remixes", duration: 180, isrc: "XXAAA2600001"
}), "remix");
`
	salida := ejecutarLogicaExtension(t, "ytmusic-spotiflac", guion)
	exigirCamposBase(t, salida, "real", "ytmusic-spotiflac")
	exigir(t, salida, "remix-name=BbY WOW (Remix)")
}

func TestSoundcloudFormateadorEmiteIdentidad(t *testing.T) {
	guion := ayudaVolcado + `
volcar(formatTrack({
  id: 42, title: "BbY WOW", user: { username: "KAROL G" },
  publisher_metadata: { artist: "KAROL G",
    album_title: "NO ME ARREPIENTO DE SENTIR TANTO", isrc: "USUG12607940" },
  full_duration: 225000
}), "real");
`
	salida := ejecutarLogicaExtension(t, "soundcloud", guion)
	exigirCamposBase(t, salida, "real", "soundcloud")
}

func TestPandoraFormateadorEmiteIdentidad(t *testing.T) {
	guion := ayudaVolcado + `
volcar(buildTrackMetadata({
  pandoraID: "TR:123",
  entity: { title: "BbY WOW", artistName: "KAROL G" },
  deezerTrack: { title: "BbY WOW", duration: 225, isrc: "USUG12607940",
    artist: { id: 1, name: "KAROL G" },
    album: { id: 9, title: "NO ME ARREPIENTO DE SENTIR TANTO", nb_tracks: 1 } },
  deezerAlbum: { id: 9, title: "NO ME ARREPIENTO DE SENTIR TANTO", nb_tracks: 1,
    artist: { name: "KAROL G" } },
  pretty: {}
}), "real");
`
	salida := ejecutarLogicaExtension(t, "pandora", guion)
	exigirCamposBase(t, salida, "real", "pandora")
}

// spotify-web no tiene un formatTrack único: arma el track en línea y completa
// la identidad con applyMetadataFallbacks desde la metadata nativa. Se prueba
// ese completado, que es lo que hace que un resultado de búsqueda sin ISRC
// termine con ISRC.
func TestSpotifyCompletaIdentidadConMetadataNativa(t *testing.T) {
	guion := `
var base = { name: "BbY WOW", artists: "KAROL G",
  album_name: "NO ME ARREPIENTO DE SENTIR TANTO", duration_ms: 225000,
  isrc: "", provider_id: "spotify-web", item_type: "track" };
var out = applyMetadataFallbacks(base, { isrc: "USUG12607940" });
console.log("isrc=" + out.isrc);
console.log("album=" + out.album_name);
console.log("name=" + out.name);
`
	salida := ejecutarLogicaExtension(t, "spotify-web", guion)
	exigir(t, salida, "isrc=USUG12607940")
	exigir(t, salida, "album=NO ME ARREPIENTO DE SENTIR TANTO")
	exigir(t, salida, "name=BbY WOW")
}

// exigirCamposBase comprueba los cinco campos de identidad compartidos por los
// volcados "real" de cada extensión.
func exigirCamposBase(t *testing.T, salida, etiqueta, provider string) {
	t.Helper()
	exigir(t, salida, etiqueta+"-name=BbY WOW")
	exigir(t, salida, etiqueta+"-artists=KAROL G")
	exigir(t, salida, etiqueta+"-album=NO ME ARREPIENTO DE SENTIR TANTO")
	exigir(t, salida, etiqueta+"-duration=225000")
	exigir(t, salida, etiqueta+"-isrc=USUG12607940")
	exigir(t, salida, etiqueta+"-provider="+provider)
}
