package flacrescue

// arcod_acceso_test.go — Fija la CONFIGURACIÓN del canal arcod: el campo
// "arcod" (apagado o instancia propia) y el Bearer opcional de esa instancia.
//
// Por qué importa el Bearer: la instancia pública hoy no pide cuenta, pero una
// PROPIA sí puede exigir sesión para el stream. Con el token configurado el
// canal sigue funcionando sin tocar la app.
//
// Nunca sale a Internet.

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

const (
	arcodPropio = "https://mi-arcod.example"
	isrcPrueba  = "QMFMF2447055"
)

func TestAjusteArcodInvitadoApagaYURLEnciende(t *testing.T) {
	cliente := NewClient()

	// off apaga, sin tocar la dirección.
	cliente.aplicarAjusteArcod(map[string]string{"arcod": "off"})
	if cliente.arcodEncendido() {
		t.Fatal("off debería apagar el canal")
	}
	if got := cliente.baseArcodActiva(); got != baseArcod {
		t.Fatalf("apagar no debe cambiar la dirección: %q", got)
	}

	// Una URL apunta el canal a la instancia propia y lo enciende; la barra
	// final se recorta para no armar "host//api/...".
	cliente.aplicarAjusteArcod(map[string]string{"arcod": arcodPropio + "/"})
	if !cliente.arcodEncendido() {
		t.Fatal("una URL debería encender el canal")
	}
	if got := cliente.baseArcodActiva(); got != arcodPropio {
		t.Fatalf("dirección mal aplicada: %q", got)
	}

	// Un valor que no es URL ni off no apaga (mismo criterio que los sitios).
	cliente.aplicarAjusteArcod(map[string]string{"arcod": "arcod"})
	if !cliente.arcodEncendido() {
		t.Fatal("un valor desconocido no debería apagar el canal")
	}

	// Un vacío NO cambia lo que ya había: en Ajustes no se distingue de
	// "sin tocar".
	cliente.aplicarAjusteArcod(map[string]string{"arcod": "", "arcod_token": ""})
	if !cliente.arcodEncendido() || cliente.baseArcodActiva() != arcodPropio {
		t.Fatal("un ajuste vacío no debería cambiar nada")
	}
}

func TestAjusteArcodGuardaElBearer(t *testing.T) {
	cliente := NewClient()
	if cliente.tokenArcod() != "" {
		t.Fatal("sin ajuste, el canal no lleva Bearer")
	}
	cliente.aplicarAjusteArcod(map[string]string{"arcod_token": "  jwt-de-prueba  "})
	if got := cliente.tokenArcod(); got != "jwt-de-prueba" {
		t.Fatalf("token mal guardado: %q", got)
	}
	// Un ajuste de solo encendido no puede borrar el token ya configurado.
	cliente.aplicarAjusteArcod(map[string]string{"arcod": "off"})
	if got := cliente.tokenArcod(); got != "jwt-de-prueba" {
		t.Fatalf("apagar no debe borrar el token: %q", got)
	}
}

func TestBaseArcodRechazaValorQueNoEsURL(t *testing.T) {
	cliente := NewClient()
	cliente.aplicarAjusteArcod(map[string]string{"arcod": "no-es-una-url"})
	if got := cliente.baseArcodActiva(); got != baseArcod {
		t.Fatalf("sin URL válida se usa la instancia pública: %q", got)
	}
}

// servidorArcodPropio imita una instancia PROPIA que exige sesión: anota el
// Bearer de cada petición y solo responde con datos si viene.
func servidorArcodPropio(t *testing.T, registro *map[string]string, mu *sync.Mutex) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		(*registro)[r.URL.Path] = r.Header.Get("Authorization")
		mu.Unlock()
		switch {
		case r.URL.Path == "/api/v2/guest/rate-limit":
			_, _ = w.Write([]byte(`{"remaining":999999,"isLimited":false}`))
		case r.URL.Path == "/api/get-music":
			_, _ = w.Write([]byte(jsonCatalogoArcod))
		case strings.HasPrefix(r.URL.Path, "/api/player/stream/"):
			_, _ = w.Write([]byte(jsonStreamArcod))
		default:
			t.Errorf("petición inesperada: %s", r.URL.Path)
		}
	}))
}

func TestCanalArcodMandaElBearerDeLaInstanciaPropia(t *testing.T) {
	vistos := map[string]string{}
	var mu sync.Mutex
	srv := servidorArcodPropio(t, &vistos, &mu)
	defer srv.Close()

	cliente := NewClient()
	cliente.aplicarAjusteArcod(map[string]string{
		"arcod":       srv.URL,
		"arcod_token": "jwt-de-prueba",
	})
	if _, err := cliente.resolverArcod(isrcPrueba, "FLAC"); err != nil {
		t.Fatalf("debería resolver contra la instancia propia: %v", err)
	}

	mu.Lock()
	defer mu.Unlock()
	// Las dos peticiones del canal llevan el mismo Bearer: sin esto, una
	// instancia que exija sesión rechazaría la búsqueda o el stream.
	for _, ruta := range []string{"/api/get-music", "/api/player/stream/312055179"} {
		if got := vistos[ruta]; got != "Bearer jwt-de-prueba" {
			t.Fatalf("%s debería llevar el Bearer, llevó %q", ruta, got)
		}
	}
}

func TestCanalArcodSinTokenNoMandaAuthorization(t *testing.T) {
	vistos := map[string]string{}
	var mu sync.Mutex
	srv := servidorArcodPropio(t, &vistos, &mu)
	defer srv.Close()

	cliente := NewClient()
	cliente.aplicarAjusteArcod(map[string]string{"arcod": srv.URL})
	if _, err := cliente.resolverArcod(isrcPrueba, "FLAC"); err != nil {
		t.Fatalf("debería resolver sin token: %v", err)
	}

	mu.Lock()
	defer mu.Unlock()
	if got := vistos["/api/get-music"]; got != "" {
		t.Fatalf("sin token no debería viajar Authorization: %q", got)
	}
}
