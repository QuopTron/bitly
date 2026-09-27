package gobackend

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/sessionpool"
)

// estadoDePool extrae el informe del JSON que devuelve la acción.
func estadoDePool(t *testing.T, respuesta string) sessionpool.DiagnosticoPool {
	t.Helper()
	var salida struct {
		OK     bool                        `json:"ok"`
		Result sessionpool.DiagnosticoPool `json:"result"`
	}
	if err := json.Unmarshal([]byte(respuesta), &salida); err != nil {
		t.Fatalf("respuesta no es JSON: %v (%s)", err, respuesta)
	}
	if !salida.OK {
		t.Fatalf("la acción no reportó ok: %s", respuesta)
	}
	return salida.Result
}

// TestAccionEstadoPoolSoloAtiendeQobuz: el contrato tiene que dejar pasar a los
// demás providers para que sigan por el camino normal de las extensiones JS.
func TestAccionEstadoPoolSoloAtiendeQobuz(t *testing.T) {
	if _, manejada := invocarAccionQobuzWeb("tidal-web", "estadoPool"); manejada {
		t.Error("qobuz-web no debe manejar acciones de tidal-web")
	}
	if _, manejada := invocarAccionQobuzWeb("qobuz-web", "estadoPool"); !manejada {
		t.Error("qobuz-web debe manejar estadoPool")
	}
	if _, manejada := invocarAccionQobuzWeb("qobuz-web", "algoMas"); !manejada {
		t.Error("una acción desconocida de qobuz-web también se maneja (con error)")
	}
}

// TestAccionEstadoPoolDistingueFuenteCaidaDeSinTokens es el punto del pedido:
// antes los dos casos se veían igual (silencio). La acción tiene que nombrarlos.
//
// Se corren los dos casos OFFLINE: cuando la lista no trae credenciales con
// forma de credencial no hay validación, así que nada sale a la red.
func TestAccionEstadoPoolDistingueFuenteCaidaDeSinTokens(t *testing.T) {
	previo := getAjustesExtension("qobuz-web")
	t.Cleanup(func() { setAjustesExtension("qobuz-web", previo) })

	// Caso 1: la URL del pool no responde (404).
	caida := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	t.Cleanup(caida.Close)
	setAjustesExtension("qobuz-web", map[string]string{"qobuzPoolUrls": caida.URL + "/pool"})

	resp, manejada := invocarAccionQobuzWeb("qobuz-web", "estadoPool")
	if !manejada {
		t.Fatal("la acción no fue manejada")
	}
	diag := estadoDePool(t, resp)
	if diag.Estado != sessionpool.EstadoPoolFuenteCaida {
		t.Fatalf("estado = %q, se esperaba %q (detalle: %s)", diag.Estado, sessionpool.EstadoPoolFuenteCaida, diag.Detalle)
	}

	// Caso 2: la URL responde, pero sin credenciales usables.
	vacia := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("<!-- sin credenciales -->"))
	}))
	t.Cleanup(vacia.Close)
	setAjustesExtension("qobuz-web", map[string]string{"qobuzPoolUrls": vacia.URL + "/pool"})

	resp, manejada = invocarAccionQobuzWeb("qobuz-web", "estadoPool")
	if !manejada {
		t.Fatal("la acción no fue manejada")
	}
	diag = estadoDePool(t, resp)
	if diag.Estado != sessionpool.EstadoPoolSinTokens {
		t.Fatalf("estado = %q, se esperaba %q (detalle: %s)", diag.Estado, sessionpool.EstadoPoolSinTokens, diag.Detalle)
	}
}
