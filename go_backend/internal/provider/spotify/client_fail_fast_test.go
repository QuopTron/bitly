package spotify

import (
	"errors"
	"net/http"
	"sync/atomic"
	"testing"
	"time"
)

// TestSearchTracks_SinCredenciales_FallaRapido fija el bug que clavaba la
// búsqueda entera en el timeout global (4 s) en CADA consulta.
//
// El cliente nativo se registra en el backend con credenciales vacías
// (internal/gobackend/exports_init_providers.go) y no existe ningún setter
// para inyectarlas después, así que siempre iba a fallar. Antes lo hacía
// mal: pedía el token con Basic Auth vacío, Spotify contestaba 400, el token
// quedaba vacío y la petición siguiente se iba en 401 → el reintento de doGet
// se llamaba a sí mismo sin contador. Ese bucle no terminaba nunca.
//
// Ahora: error inmediato y CERO peticiones de red.
func TestSearchTracks_SinCredenciales_FallaRapido(t *testing.T) {
	var peticiones int32
	c := &Client{
		http: &http.Client{Transport: &mockTransport{roundTrip: func(*http.Request) (*http.Response, error) {
			atomic.AddInt32(&peticiones, 1)
			return okJSON(map[string]interface{}{"access_token": "x"}), nil
		}}},
	}

	inicio := time.Now()
	_, err := c.SearchTracks("cualquiera", 5)
	transcurrido := time.Since(inicio)

	if err == nil {
		t.Fatal("esperaba error sin credenciales")
	}
	if !errors.Is(err, errSinCredenciales) {
		t.Fatalf("esperaba errSinCredenciales, obtuve: %v", err)
	}
	if n := atomic.LoadInt32(&peticiones); n != 0 {
		t.Fatalf("no debía tocar la red, hizo %d peticiones", n)
	}
	if transcurrido > time.Second {
		t.Fatalf("debe fallar al instante, tardó %v", transcurrido)
	}
}

// TestDoGet_Reintenta401UnaSolaVez guarda el otro extremo: con credenciales
// puestas pero rechazadas (401), el cliente debe intentar UNA vez más y
// rendirse. Si alguien reintroduce la recursión sin contador, este test no
// falla con un mensaje: se queda colgado hasta que vence el timeout de `go
// test`, que es exactamente el síntoma que tenía la app.
func TestDoGet_Reintenta401UnaSolaVez(t *testing.T) {
	var peticiones int32
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		atomic.AddInt32(&peticiones, 1)
		return &http.Response{
			StatusCode: http.StatusUnauthorized,
			Status:     "401 Unauthorized",
			Body:       http.NoBody,
			Header:     make(http.Header),
		}, nil
	})

	hecho := make(chan error, 1)
	go func() {
		hecho <- c.doGet("/search", map[string]string{"q": "x"}, &struct{}{})
	}()

	select {
	case err := <-hecho:
		if err == nil {
			t.Fatal("esperaba error tras el 401")
		}
	case <-time.After(5 * time.Second):
		t.Fatal("doGet no terminó: volvió la recursión infinita del 401")
	}

	// 2 tokens + 2 GET: el original y un único reintento.
	if n := atomic.LoadInt32(&peticiones); n > 4 {
		t.Fatalf("demasiados reintentos: %d peticiones", n)
	}
}
