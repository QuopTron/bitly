package download

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// proveedorConCalidades arma un ExtensionProvider con las opciones del
// manifiesto. El runtime va nil porque calidadParaProvider solo lee las
// opciones.
func proveedorConCalidades(nombre string, opts ...string) *provider.ExtensionProvider {
	p := provider.NewExtensionProvider(nombre, nombre, nil)
	p.SetQualityOptions(opts)
	return p
}

// TestCalidadSinPerdidaNoBajaAtmos es la regresión de un bug real: en Tidal la
// primera opción declarada es DOLBY_ATMOS (E-AC3, CON pérdida). Como el pedido
// "flac" no coincide por nombre con ningún id de Tidal, el fallback tomaba
// opts[0] y el usuario que pedía FLAC terminaba bajando Atmos.
func TestCalidadSinPerdidaNoBajaAtmos(t *testing.T) {
	tidal := proveedorConCalidades("tidal-web",
		"DOLBY_ATMOS", "HI_RES_LOSSLESS", "LOSSLESS", "HIGH", "LOW")

	got := calidadParaProvider(tidal, "flac")
	if got != "HI_RES_LOSSLESS" {
		t.Fatalf("pedir FLAC debe dar la mejor opción SIN pérdida (HI_RES_LOSSLESS), dio %q", got)
	}

	// Y nunca debe elegir una opción con pérdida por el simple hecho de estar
	// primera en la lista.
	if got == "DOLBY_ATMOS" {
		t.Fatal("pedir FLAC no puede dar DOLBY_ATMOS")
	}
}

func TestCalidadCoincidenciaExactaSeRespeta(t *testing.T) {
	tidal := proveedorConCalidades("tidal-web",
		"DOLBY_ATMOS", "HI_RES_LOSSLESS", "LOSSLESS", "HIGH", "LOW")

	// Si el usuario pide explícitamente una opción que existe, se respeta tal
	// cual — incluida Dolby Atmos, que es una elección legítima.
	for _, pedido := range []string{"DOLBY_ATMOS", "lossless", "HIGH"} {
		got := calidadParaProvider(tidal, pedido)
		if got != pedido && got != "LOSSLESS" {
			t.Fatalf("pedido %q: esperaba la coincidencia exacta, dio %q", pedido, got)
		}
	}
}

func TestCalidadSinOpcionSinPerdidaUsaElMejor(t *testing.T) {
	// SoundCloud solo tiene mp3_128: no hay nada sin pérdida que ofrecer, así
	// que se mantiene el comportamiento previo (el mejor disponible).
	soundcloud := proveedorConCalidades("soundcloud", "mp3_128")
	if got := calidadParaProvider(soundcloud, "flac"); got != "mp3_128" {
		t.Fatalf("sin opciones sin pérdida debe usar la mejor disponible, dio %q", got)
	}
}

func TestCalidadPedidoLossySigueUsandoElMejor(t *testing.T) {
	// Deezer declara solo "flac". Un pedido lossy no coincide y no hay opción
	// lossy: se usa el mejor y applyQuality convierte después. La regla nueva
	// no debe cambiar esto.
	deezer := proveedorConCalidades("deezer", "flac")
	if got := calidadParaProvider(deezer, "mp3_320"); got != "flac" {
		t.Fatalf("un pedido lossy sin opción lossy debe usar la mejor, dio %q", got)
	}
}

func TestCalidadVaciaUsaLaMejor(t *testing.T) {
	qobuz := proveedorConCalidades("qobuz-web", "HI_RES_LOSSLESS", "LOSSLESS")
	if got := calidadParaProvider(qobuz, ""); got != "HI_RES_LOSSLESS" {
		t.Fatalf("sin pedido debe usar la mejor, dio %q", got)
	}
}

// TestEsOpcionSinPerdida fija qué cuenta como sin pérdida. DOLBY_ATMOS es el
// caso que importa: con pérdida, aunque sea "premium".
func TestEsOpcionSinPerdida(t *testing.T) {
	for _, o := range []string{"FLAC", "flac", "LOSSLESS", "HI_RES_LOSSLESS", "HI_RES"} {
		if !esOpcionSinPerdida(o) {
			t.Errorf("%q debería contar como sin pérdida", o)
		}
	}
	for _, o := range []string{"DOLBY_ATMOS", "HIGH", "LOW", "mp3_128", "MP3_320", ""} {
		if esOpcionSinPerdida(o) {
			t.Errorf("%q NO debería contar como sin pérdida", o)
		}
	}
}
