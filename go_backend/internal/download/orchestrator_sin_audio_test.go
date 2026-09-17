package download

import "testing"

// Los motivos que significan "este proveedor no puede servir audio ahora" se
// reconocen para no volver a intentarlo en cada descarga de la sesión; cualquier
// otro error (rate-limit, red, sin stream para ESE track) no debe marcarse,
// porque reintentarlo sí puede funcionar.
func TestEsErrorSinAudio(t *testing.T) {
	casosSinAudio := []string{
		"Amazon sin cuenta propia: el audio se resuelve desde una fuente abierta",
		"Deezer sin sesión propia: el audio se resuelve desde una fuente abierta",
		"Qobuz: sin cuenta propia (o calidad no disponible) | ",
		"TIDAL: sin sesión propia y respaldo firmado deshabilitado | ",
		"Pandora metadata-only: el audio se resuelve desde una fuente abierta",
	}
	for _, m := range casosSinAudio {
		if !esErrorSinAudio(m) {
			t.Errorf("debería marcar sin audio: %q", m)
		}
	}

	casosReintentables := []string{
		"No direct SoundCloud progressive stream found for track: 2001688815",
		"flac-rescue: sin stream",
		"spotify-web: archivo no es la cancion original",
		"HTTP 429 too many requests",
		"",
	}
	for _, m := range casosReintentables {
		if esErrorSinAudio(m) {
			t.Errorf("no debería marcar sin audio: %q", m)
		}
	}
}

func TestMarcaSinAudio(t *testing.T) {
	limpiarProvidersSinAudio()
	defer limpiarProvidersSinAudio()

	marcarProviderSinAudio("amazon", "Amazon sin cuenta propia")
	if !providerSinAudio("amazon") {
		t.Fatal("amazon debería quedar marcado")
	}
	if providerSinAudio("soundcloud") {
		t.Fatal("soundcloud no fue marcado")
	}

	// Un error que no es de la familia no marca nada.
	marcarProviderSinAudio("soundcloud", "HTTP 429")
	if providerSinAudio("soundcloud") {
		t.Fatal("un 429 no debe marcar el proveedor como sin audio")
	}

	limpiarProvidersSinAudio()
	if providerSinAudio("amazon") {
		t.Fatal("limpiarProvidersSinAudio debe olvidar las marcas")
	}
}
