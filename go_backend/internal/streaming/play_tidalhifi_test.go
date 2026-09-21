// play_tidalhifi_test.go — fija el LUGAR del canal "Tidal HiFi" en las listas
// que deciden quién entrega audio.
//
// Por qué: es catálogo de Tidal (distinto al de Qobuz) con ISRC y FLAC real sin
// sesión. Aporta IDENTIDAD a la búsqueda y AUDIO a la descarga, pero NO puede
// servir un stream (su audio llega en segmentos DASH: ver su GetStreamURL). Las
// tres listas tienen que decir exactamente eso, porque cada una se usa en un
// camino distinto:
//
//	streamingProviders    → metadata/identidad: SÍ (resuelve ISRC que Qobuz no tiene)
//	proveedoresAudio      → carrera de streaming: NO (no puede entregar un byte)
//	proveedoresSoloDescarga → descarga: SÍ, y declarado a propósito
//	proveedoresLossless   → capacidad sin pérdida: SÍ
//	fuentesLosslessSiempre → gracia en vivo sin suscripción: NO (solo descarga)
package streaming

import "testing"

func TestTidalHiFiAportaIdentidadYPeroNoStreamea(t *testing.T) {
	const canal = "tidal-hifi"

	if !contieneNombre(streamingProviders, canal) {
		t.Fatal("tidal-hifi debe buscar en metadata: es su catálogo el que aporta el ISRC")
	}
	if contieneNombre(proveedoresAudio, canal) {
		t.Fatal("tidal-hifi no puede estar en la carrera de streaming: no entrega URL reproducible")
	}
	if !contieneNombre(proveedoresSoloDescarga, canal) {
		t.Fatal("tidal-hifi debe estar declarado como solo-descarga (para que el stream lo salte a propósito)")
	}
	if !contieneNombre(proveedoresLossless, canal) {
		t.Fatal("tidal-hifi entrega FLAC real: debe figurar como fuente sin pérdida")
	}
	if contieneNombre(fuentesLosslessSiempre, canal) {
		t.Fatal("tidal-hifi no puede dar la gracia en vivo: su audio es por descarga")
	}
}
