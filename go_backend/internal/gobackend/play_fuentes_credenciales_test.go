// play_fuentes_credenciales_test.go — Fija QUÉ credenciales habilitan a una
// extensión de catálogo para entrar a la carrera de reproducción.
//
// La regla: sin credenciales propias ni del pool, la fuente queda afuera (la
// carrera es la de siempre). Con credenciales, Deezer/Qobuz/Tidal pueden
// entregar su audio en vivo (y su FLAC cuando se pidió sin pérdida).
package gobackend

import "testing"

// guardaAjustesRestaura guarda y restaura los ajustes de las extensiones que
// toca el test, para no ensuciar el estado global.
func guardaAjustesRestaura(t *testing.T, ids ...string) {
	t.Helper()
	previos := map[string]map[string]string{}
	for _, id := range ids {
		previos[id] = getAjustesExtension(id)
	}
	t.Cleanup(func() {
		for _, id := range ids {
			setAjustesExtension(id, previos[id])
		}
	})
}

func TestCredencialesDeExtension(t *testing.T) {
	const deezer, qobuz, tidal = "deezer", "qobuz-web", "tidal-web"
	guardaAjustesRestaura(t, deezer, qobuz, tidal)

	casos := []struct {
		nombre string
		id     string
		ajuste map[string]string
		quiere bool
	}{
		{"deezer sin credenciales", deezer, map[string]string{}, false},
		{"deezer con ARL propia", deezer, map[string]string{"arl": "arl-viva"}, true},
		{"deezer con pool", deezer, map[string]string{"arlPool": "a\nb"}, true},
		{"qobuz sin credenciales", qobuz, map[string]string{}, false},
		{"qobuz solo email", qobuz, map[string]string{"email": "a@b.c"}, false},
		{"qobuz email+password", qobuz, map[string]string{"email": "a@b.c", "password": "x"}, true},
		{"qobuz con pool", qobuz, map[string]string{"qobuzPool": "a@b.c:x"}, true},
		{"tidal sin credenciales", tidal, map[string]string{}, false},
		{"tidal con token", tidal, map[string]string{"tidalAccessToken": "tok"}, true},
		{"tidal con pool", tidal, map[string]string{"tidalTokenPool": "t1\nt2"}, true},
	}
	for _, caso := range casos {
		setAjustesExtension(caso.id, caso.ajuste)
		for _, otro := range []string{deezer, qobuz, tidal} {
			if otro != caso.id {
				setAjustesExtension(otro, map[string]string{})
			}
		}
		if got := credencialesDeExtension(caso.id); got != caso.quiere {
			t.Errorf("%s: credencialesDeExtension(%q) = %v, se esperaba %v", caso.nombre, caso.id, got, caso.quiere)
		}
	}

	// Una fuente sin clave de credencial declarada no entra a ciegas.
	if credencialesDeExtension("amazon") {
		t.Error("amazon no tiene clave de credencial declarada: no debe habilitarse sola")
	}
	if credencialesDeExtension("") {
		t.Error("un nombre vacío nunca puede habilitar una fuente")
	}
}
