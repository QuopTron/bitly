// ─────────────────────────────────────────────────────────────
// play_sesion_fuentes_test.go — Fija la AMPLIACIÓN de la carrera de audio
// a las fuentes que pueden streamear con su sesión ya lista.
//
// Qué cambió: la lista fija (proveedoresAudio) sigue siendo la misma y sigue
// sin depender de sesión, así que la política de "los catálogos buscan, no
// streamean" no cambia cuando nadie configuró nada. Lo nuevo es que una
// extensión de descarga cuya sesión firmada ya está usable (cuenta propia o
// credencial del pool) entra a la carrera — al final en pérdida, y con el
// primer turno en sin pérdida cuando puede dar FLAC.
//
// Por qué así: la exclusión vieja era correcta mientras la fuente no tenía
// sesión (gastaba 1,5-5,8s por turno devolviendo nada), pero también dejaba
// afuera a Deezer/Qobuz/Tidal/Amazon cuando el usuario SÍ tiene credenciales.
//
// Se conecta con: rescue_order.go (ordenProvidersStreaming,
// ordenProvidersStreamingCalidad, fuentesAudioConSesion) y rescue_lossless.go
// (fuentesLosslessDeStreaming).

package streaming

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// conSesion sustituye el predicado de credenciales durante el test.
func conSesion(t *testing.T, lista bool) {
	t.Helper()
	previo := fuentePuedeStreamear
	fuentePuedeStreamear = func(string) bool { return lista }
	t.Cleanup(func() { fuentePuedeStreamear = previo })
}

// armaRegistryConCatalogo registra la cadena fija más dos extensiones de
// catálogo que podrían streamear si tuvieran sesión.
func armaRegistryConCatalogo() *provider.Registry {
	reg := provider.NewRegistry()
	for _, n := range []string{
		"ytmusic-spotiflac", "youtube", "internetarchive", "flac-rescue",
		"soundcloud", "qobuz-web", "deezer",
	} {
		name := n
		reg.Register(&stubProvider{name: name, resolve: func() (string, error) {
			return "", errSinStream
		}})
	}
	return reg
}

// TestFuentesConSesionEntranDespuesDeLaFija: con sesión lista, las extensiones
// de catálogo se suman AL FINAL de la lista fija — sin tocar proveedoresAudio.
func TestFuentesConSesionEntranDespuesDeLaFija(t *testing.T) {
	conSesion(t, true)
	reg := armaRegistryConCatalogo()

	orden := ordenProvidersStreaming(reg)
	for i, n := range proveedoresAudio {
		if orden[i] != n {
			t.Fatalf("la lista fija cambió de lugar: orden[%d]=%q, se esperaba %q", i, orden[i], n)
		}
	}
	if !contieneNombre(orden, "qobuz-web") || !contieneNombre(orden, "deezer") {
		t.Fatalf("las fuentes con sesión no entraron a la carrera: %v", orden)
	}
	// La política estática no se movió: los catálogos siguen fuera de la lista
	// fija y esProviderStreaming sigue devolviendo false para ellos.
	if contieneNombre(proveedoresAudio, "qobuz-web") || esProviderStreaming("qobuz-web") {
		t.Fatal("la lista fija se contaminó; la ampliación debe ser dinámica")
	}
}

// TestFuentesConSesionNoEntranSinSesion: sin sesión, la carrera es la de
// siempre. Es el caso de fábrica (nadie configuró nada) y no puede cambiar.
func TestFuentesConSesionNoEntranSinSesion(t *testing.T) {
	conSesion(t, false)
	reg := armaRegistryConCatalogo()

	orden := ordenProvidersStreaming(reg)
	if contieneNombre(orden, "qobuz-web") || contieneNombre(orden, "deezer") {
		t.Fatalf("sin sesión una fuente que no puede streamear entró igual: %v", orden)
	}
	if len(orden) != len(proveedoresAudio) {
		t.Fatalf("sin sesión la carrera debe ser la lista fija (%d), es %d: %v",
			len(proveedoresAudio), len(orden), orden)
	}
}

// TestFuentesLosslessDeStreamingSumaCatalogoConSesion: el canal sin pérdida
// también consulta al catálogo con sesión, porque puede entregar FLAC en vivo.
func TestFuentesLosslessDeStreamingSumaCatalogoConSesion(t *testing.T) {
	conSesion(t, true)
	reg := armaRegistryConCatalogo()

	lossless := fuentesLosslessDeStreaming(reg)
	if !contieneNombre(lossless, "qobuz-web") || !contieneNombre(lossless, "deezer") {
		t.Fatalf("el catálogo con sesión debe entrar al canal sin pérdida: %v", lossless)
	}
	if contieneNombre(lossless, "soundcloud") {
		t.Fatalf("soundcloud no entrega sin pérdida y no puede entrar al canal: %v", lossless)
	}

	conSesion(t, false)
	reg2 := armaRegistryConCatalogo()
	sinSesion := fuentesLosslessDeStreaming(reg2)
	if contieneNombre(sinSesion, "qobuz-web") || contieneNombre(sinSesion, "deezer") {
		t.Fatalf("sin sesión el catálogo no puede streamear FLAC: %v", sinSesion)
	}
}

// TestOrdenSinPerdidaPonePrimeroElCatalogoConSesion: con "flac" el catálogo con
// sesión va antes que los re-subidos, igual que Internet Archive/flac-rescue.
func TestOrdenSinPerdidaPonePrimeroElCatalogoConSesion(t *testing.T) {
	conSesion(t, true)
	reg := armaRegistryConCatalogo()

	orden := ordenProvidersStreamingCalidad(reg, "flac")
	posQobuz, posYoutube := -1, -1
	for i, n := range orden {
		switch n {
		case "qobuz-web":
			posQobuz = i
		case "ytmusic-spotiflac":
			posYoutube = i
		}
	}
	if posQobuz < 0 {
		t.Fatalf("qobuz-web no quedó en el orden: %v", orden)
	}
	if posYoutube < 0 {
		t.Fatalf("ytmusic-spotiflac desapareció del orden: %v", orden)
	}
	if posQobuz > posYoutube {
		t.Fatalf("con FLAC el catálogo con sesión debe ir antes del re-subido: %v", orden)
	}
}
