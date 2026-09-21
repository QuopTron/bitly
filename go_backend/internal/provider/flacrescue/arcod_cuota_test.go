// ─────────────────────────────────────────────────────────────
// arcod_cuota_test.go — Fija las dos defensas que hacen que el canal
// arcod no cueste latencia cuando el sitio no puede dar nada:
//
//  1. El presupuesto que el sitio publica por IP se lee (con caché) y,
//     si dice que estamos limitados, el canal se saltea SIN gastar la
//     búsqueda ni el stream.
//  2. Los fallos de pool suben el backoff (5 → 10 → 20 → 40 → 60 min)
//     y el primer acierto lo borra.
//
// Nunca sale a Internet: todo contra un servidor de prueba.
//
// Se conecta con: arcod_cuota.go y arcod_flujo_test.go (servidorArcod).
// Parte del flujo: rescate de FLAC por stream y por descarga.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// servidorArcodLimitado imita al sitio cuando avisa que no queda presupuesto
// de invitado, y anota TODO lo que se le pide (para probar que no se pide nada).
func servidorArcodLimitado(t *testing.T, registro *registroArcod) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		registro.anotar(&registro.cuotas, r.URL.Path)
		if r.URL.Path == "/api/v2/guest/rate-limit" {
			_, _ = w.Write([]byte(`{"remaining":3,"isLimited":false}`))
			return
		}
		if r.URL.Path == "/api/get-music" {
			registro.anotar(&registro.busquedas, r.URL.Query().Get("q"))
			_, _ = w.Write([]byte(jsonCatalogoArcod))
			return
		}
		registro.anotar(&registro.streams, r.URL.Path)
		_, _ = w.Write([]byte(jsonStreamArcod))
	}))
}

// TestArcodConPresupuestoBajoNoGastaNada: si el sitio dice que quedan pocas
// resoluciones, el canal no pide ni la búsqueda: se corre para que la cuota
// alcance para lo que el usuario realmente escucha.
func TestArcodConPresupuestoBajoNoGastaNada(t *testing.T) {
	registro := &registroArcod{}
	srv := servidorArcodLimitado(t, registro)
	defer srv.Close()

	cliente := clienteArcod(srv)
	if _, err := cliente.resolverArcod("QMFMF2447055", "FLAC"); err == nil {
		t.Fatal("con presupuesto agotado no puede resolver")
	}
	if b := registro.leer(&registro.busquedas); len(b) != 0 {
		t.Fatalf("no debería buscar en el catálogo: %v", b)
	}
	if s := registro.leer(&registro.streams); len(s) != 0 {
		t.Fatalf("no debería pedir el stream: %v", s)
	}
	// Y queda en pausa: la próxima canción tampoco paga la consulta.
	if _, err := cliente.resolverArcod("QMFMF2447055", "FLAC"); err == nil {
		t.Fatal("en pausa tampoco puede resolver")
	}
}

// TestArcodConsultaElPresupuestoUnaVezPorMinuto: la respuesta se recuerda, así
// el chequeo no suma una petición por canción.
func TestArcodConsultaElPresupuestoUnaVezPorMinuto(t *testing.T) {
	registro := &registroArcod{}
	srv := servidorArcod(t, false, registro)
	defer srv.Close()

	cliente := clienteArcod(srv)
	for i := 0; i < 3; i++ {
		if _, err := cliente.resolverArcod("QMFMF2447055", "FLAC"); err != nil {
			t.Fatalf("intento %d: %v", i+1, err)
		}
	}
	if c := registro.leer(&registro.cuotas); len(c) != 1 {
		t.Fatalf("el presupuesto debería consultarse una sola vez: %v", c)
	}
}

// TestArcodBackoffCreceYSeBorraConUnAcierto: una caída del pool no puede
// costar lo mismo la primera vez que la quinta.
func TestArcodBackoffCreceYSeBorraConUnAcierto(t *testing.T) {
	cliente := NewClient()
	esperado := []time.Duration{5, 10, 20, 40, 60, 60}
	for i, minutos := range esperado {
		antes := time.Now()
		cliente.marcarFalloArcod()
		cliente.arcodEstadoMu.Lock()
		pausa := cliente.arcodPausaHasta.Sub(antes)
		cliente.arcodEstadoMu.Unlock()
		objetivo := time.Duration(minutos) * time.Minute
		if pausa < objetivo-time.Second || pausa > objetivo+time.Second {
			t.Fatalf("fallo %d: pausa %s, se esperaba %s", i+1, pausa, objetivo)
		}
	}
	if !cliente.enPausaArcod() {
		t.Fatal("con fallos seguidos el canal debe quedar en pausa")
	}
	cliente.marcarAciertoArcod()
	if cliente.enPausaArcod() {
		t.Fatal("un acierto debe borrar la pausa")
	}
	cliente.arcodEstadoMu.Lock()
	fallos := cliente.arcodFallos
	cliente.arcodEstadoMu.Unlock()
	if fallos != 0 {
		t.Fatalf("el contador de fallos debe volver a cero, quedó en %d", fallos)
	}
}

// TestArcodSinDatoDePresupuestoNoBloquea: si el sitio no publica el
// presupuesto (endpoint ausente o ilegible), el canal resuelve igual —
// best-effort, nunca se apaga por una consulta que no es suya.
func TestArcodSinDatoDePresupuestoNoBloquea(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v2/guest/rate-limit":
			w.WriteHeader(http.StatusNotFound)
		case "/api/get-music":
			_, _ = w.Write([]byte(jsonCatalogoArcod))
		default:
			_, _ = w.Write([]byte(jsonStreamArcod))
		}
	}))
	defer srv.Close()

	cliente := clienteArcod(srv)
	if _, err := cliente.resolverArcod("QMFMF2447055", "FLAC"); err != nil {
		t.Fatalf("sin dato de presupuesto debería resolver igual: %v", err)
	}
}
