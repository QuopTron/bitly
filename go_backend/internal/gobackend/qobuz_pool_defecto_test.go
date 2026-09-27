package gobackend

import (
	"strings"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/sessionpool"
)

// TestQobuzPoolUsaElOrigenDeFabricaSiNoHayURLPropia fija el punto del pedido:
// sin `qobuzPoolUrls`, el pool de Qobuz se arma con el origen de FÁBRICA (el
// /pool del Worker propio). Sin esto, "apuntado por defecto" sería letra muerta.
func TestQobuzPoolUsaElOrigenDeFabricaSiNoHayURLPropia(t *testing.T) {
	// El default de fábrica viaja INYECTADO en el build (ver
	// sessionpool.QobuzPoolURLInyectada): en el fuente está vacío a propósito.
	// Acá se pone uno para ejercitar el camino.
	previos := sessionpool.QobuzPoolURLsPorDefecto
	sessionpool.QobuzPoolURLsPorDefecto = []string{"https://fabrica.example/pool/s3cr3to"}
	t.Cleanup(func() { sessionpool.QobuzPoolURLsPorDefecto = previos })

	got := fuentesPoolQobuz(map[string]string{})
	if len(got) != len(sessionpool.QobuzPoolURLsPorDefecto) {
		t.Fatalf("fuentes = %v, se esperaba el default %v", got, sessionpool.QobuzPoolURLsPorDefecto)
	}
	for i, u := range sessionpool.QobuzPoolURLsPorDefecto {
		if got[i] != u {
			t.Errorf("fuente[%d] = %q, se esperaba %q", i, got[i], u)
		}
	}
}

// TestQobuzPoolURLPropiaReemplazaAlDefault fija que una URL del usuario MANDA y
// el default NO se suma. Además de ser lo esperable, es la forma de apagar el
// de fábrica (poner cualquier URL propia).
func TestQobuzPoolURLPropiaReemplazaAlDefault(t *testing.T) {
	previos := sessionpool.QobuzPoolURLsPorDefecto
	sessionpool.QobuzPoolURLsPorDefecto = []string{"https://fabrica.example/pool/s3cr3to"}
	t.Cleanup(func() { sessionpool.QobuzPoolURLsPorDefecto = previos })

	propia := "https://mi-pool.example/qobuz"
	got := fuentesPoolQobuz(map[string]string{"qobuzPoolUrls": propia})
	if len(got) != 1 || got[0] != propia {
		t.Fatalf("fuentes = %v, se esperaba sólo %q", got, propia)
	}
	for _, u := range got {
		if u == sessionpool.QobuzPoolURLsPorDefecto[0] {
			t.Fatalf("el default se sumó a la URL propia: %v", got)
		}
	}
}

// TestTieneFuentesDePoolReconoceElOrigenDeFabricaDeQobuz: el push de arranque
// llega con los ajustes VACÍOS cuando el usuario no configuró nada; el gate
// tiene que reconocer el origen de fábrica de Qobuz para que la goroutine del
// pool corra. Para las demás extensiones, sin fuentes no se toca la red.
func TestTieneFuentesDePoolReconoceElOrigenDeFabricaDeQobuz(t *testing.T) {
	previos := sessionpool.QobuzPoolURLsPorDefecto
	sessionpool.QobuzPoolURLsPorDefecto = []string{"https://fabrica.example/pool/s3cr3to"}
	t.Cleanup(func() { sessionpool.QobuzPoolURLsPorDefecto = previos })

	if !tieneFuentesDePool("qobuz-web", map[string]string{}) {
		t.Error("qobuz-web con origen de fábrica debería armar pool")
	}
	if tieneFuentesDePool("tidal-web", map[string]string{}) {
		t.Error("tidal-web sin fuentes no debería armar pool")
	}

	// Un build SIN el Worker inyectado llega con el default vacío: no hay nada
	// que bajar y no se toca la red.
	sessionpool.QobuzPoolURLsPorDefecto = nil
	if tieneFuentesDePool("qobuz-web", map[string]string{}) {
		t.Error("qobuz-web sin origen de fábrica no debería armar pool")
	}
}

// TestExtraerCredencialesQobuzLeeElFormatoDelPoolDelWorker cierra el contrato
// entre el Worker (GET /pool) y el backend: el Worker sirve una línea
// "user_auth_token=<token>"; el extractor tiene que sacar los tokens de ahí.
// Si alguien cambia el formato del Worker (p. ej. tokens sueltos sin la clave),
// el pool se queda vacío en silencio y este test lo delata.
func TestExtraerCredencialesQobuzLeeElFormatoDelPoolDelWorker(t *testing.T) {
	// Tal cual lo devuelve deeplinks/proxy-qobuz/worker.js.
	cuerpo := "user_auth_token=TOKEN_UNO_1234567890\nuser_auth_token=TOKEN_DOS_0987654321\n"
	got := sessionpool.ExtraerCredencialesQobuz(cuerpo)
	if len(got) != 2 {
		t.Fatalf("extraídas = %v, se esperaban 2 tokens", got)
	}
	if got[0] != "TOKEN_UNO_1234567890" || got[1] != "TOKEN_DOS_0987654321" {
		t.Fatalf("tokens = %v, no coinciden con el cuerpo del Worker", got)
	}
}

// TestOrigenDeFabricaDeQobuzApuntaAlPoolDelWorker fija la forma del default: es
// una URL http(s) cuya ruta es /pool, o /pool/<secreto> si el Worker configuró
// QOBUZ_POOL_SECRET (las DOS formas sirven el mismo endpoint; ver
// selfhost/qobuz-pool/README.md). Un default que apunte a otra ruta no rompería
// la compilación, sólo fallaría en vivo.
func TestOrigenDeFabricaDeQobuzApuntaAlPoolDelWorker(t *testing.T) {
	for _, u := range sessionpool.QobuzPoolURLsPorDefecto {
		if !strings.HasPrefix(u, "http") {
			t.Errorf("el default no es una URL: %q", u)
		}
		i := strings.Index(u, "://")
		if i < 0 {
			t.Errorf("el default no tiene esquema: %q", u)
			continue
		}
		barra := strings.Index(u[i+3:], "/")
		if barra < 0 {
			t.Errorf("el default no apunta a /pool: %q", u)
			continue
		}
		ruta := strings.TrimRight(u[i+3+barra:], "/")
		if ruta != "/pool" && !strings.HasPrefix(ruta, "/pool/") {
			t.Errorf("el default no apunta a /pool (o /pool/<secreto>): %q", u)
		}
	}
}
