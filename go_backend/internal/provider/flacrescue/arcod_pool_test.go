// ─────────────────────────────────────────────────────────────
// arcod_pool_test.go — Fija que un 500 con el pool de tokens vacío
// cuente como fallo de pool.
//
// Por qué existe: el sitio NO contesta un JSON de error con 200 cuando se
// queda sin cuentas —contesta 500 y el motivo viaja en el cuerpo—. Sin mirar
// el cuerpo, el error quedaba como "el canal respondió 500", no activaba el
// backoff y cada canción volvía a pagar la espera (visto en el emulador:
// cinco reintentos dentro de un mismo toque).
//
// Nunca sale a Internet: todo contra un servidor de prueba.
//
// Se conecta con: arcod.go (clasificarFalloArcod) y arcod_cuota.go (la pausa).
// Parte del flujo: rescate de FLAC por stream.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

// servidorArcod500 imita al sitio en su caída REAL: 500 con el motivo del pool
// dentro del cuerpo (no un 200 con sobre de error).
func servidorArcod500(t *testing.T, registro *registroArcod) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/v2/guest/rate-limit" {
			_, _ = w.Write([]byte(`{"remaining":999999,"isLimited":false}`))
			return
		}
		if r.URL.Path == "/api/get-music" {
			registro.anotar(&registro.busquedas, r.URL.Query().Get("q"))
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte(jsonSinCuentasArcod))
			return
		}
		registro.anotar(&registro.streams, r.URL.Path)
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(jsonSinCuentasArcod))
	}))
}

// TestArcodCon500DelPoolEntraEnPausa: el 500 del pool se reconoce, deja el
// canal en pausa y la resolución siguiente NO toca la red.
func TestArcodCon500DelPoolEntraEnPausa(t *testing.T) {
	registro := &registroArcod{}
	srv := servidorArcod500(t, registro)
	defer srv.Close()

	cliente := clienteArcod(srv)
	_, err := cliente.resolverArcod("QMFMF2447055", "FLAC")
	if err == nil {
		t.Fatal("con el pool vacío no puede resolver")
	}
	if !errors.Is(err, errArcodSinCuentas) {
		t.Fatalf("el 500 del pool debe clasificarse como falta de cuentas: %v", err)
	}
	if !cliente.enPausaArcod() {
		t.Fatal("un fallo de pool debe dejar el canal en pausa")
	}

	// En pausa el canal se saltea: ni una petición más.
	antes := len(registro.leer(&registro.busquedas))
	if _, err := cliente.resolverArcod("QMFMF2447055", "FLAC"); err == nil {
		t.Fatal("en pausa no puede resolver")
	}
	if despues := len(registro.leer(&registro.busquedas)); despues != antes {
		t.Fatalf("en pausa no debe tocar la red: %d búsquedas antes, %d después", antes, despues)
	}
}

// TestArcod500AjenoNoPausaElCanal: un 500 que NO es del pool (p. ej. un error
// interno del sitio) no debe apagar el canal varios minutos.
func TestArcod500AjenoNoPausaElCanal(t *testing.T) {
	registro := &registroArcod{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/v2/guest/rate-limit" {
			_, _ = w.Write([]byte(`{"remaining":999999,"isLimited":false}`))
			return
		}
		registro.anotar(&registro.busquedas, r.URL.Query().Get("q"))
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"success":false,"error":"internal error"}`))
	}))
	defer srv.Close()

	cliente := clienteArcod(srv)
	_, err := cliente.resolverArcod("QMFMF2447055", "FLAC")
	if err == nil {
		t.Fatal("un 500 no puede resolver")
	}
	if errors.Is(err, errArcodSinCuentas) {
		t.Fatalf("un 500 ajeno NO es falta de cuentas: %v", err)
	}
	if cliente.enPausaArcod() {
		t.Fatal("un 500 ajeno no debe pausar el canal")
	}
}
