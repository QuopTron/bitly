package flacrescue

// arcod_stream_test.go — Fija las PUERTAS del enlace de audio del canal arcod:
// cuál se usa primero, que se recuerde la que funcionó y que una degradación
// (MP3 cuando se pidió sin pérdida) no pase por buena.
//
// Por qué importa: la ruta del reproductor de la instancia pública NO está en
// el repo abierto, así que una instancia PROPIA puede exponer el stream en otra
// ruta. Sin este respaldo, apuntar el canal a tu instancia no serviría de nada.
//
// Nunca sale a Internet.

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// servidorPuertasArcod imita una instancia donde SOLO responde la puerta
// indicada; las demás contestan 404. Anota cuántas veces se pidió cada ruta.
func servidorPuertasArcod(t *testing.T, abierta string) (*httptest.Server, func(string) int) {
	t.Helper()
	var mu sync.Mutex
	conteo := map[string]int{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		conteo[r.URL.Path]++
		mu.Unlock()
		switch {
		case r.URL.Path == "/api/v2/guest/rate-limit":
			_, _ = w.Write([]byte(`{"remaining":999999,"isLimited":false}`))
		case r.URL.Path == "/api/get-music":
			_, _ = w.Write([]byte(jsonCatalogoArcod))
		case strings.HasPrefix(r.URL.Path, "/api/player/stream/"):
			if abierta != "player" {
				w.WriteHeader(http.StatusNotFound)
				return
			}
			_, _ = w.Write([]byte(jsonStreamArcod))
		case strings.HasPrefix(r.URL.Path, "/v2/stream/"):
			if abierta != "servidor" {
				w.WriteHeader(http.StatusNotFound)
				return
			}
			_, _ = w.Write([]byte(jsonStreamArcod))
		default:
			t.Errorf("petición inesperada: %s", r.URL.Path)
		}
	}))
	leer := func(ruta string) int {
		mu.Lock()
		defer mu.Unlock()
		return conteo[ruta]
	}
	return srv, leer
}

func TestCanalArcodUsaLaPuertaDelServidorYLaRecuerda(t *testing.T) {
	srv, conteo := servidorPuertasArcod(t, "servidor")
	defer srv.Close()

	cliente := clienteArcod(srv)
	enlace, err := cliente.resolverArcod(isrcPrueba, "FLAC")
	if err != nil {
		t.Fatalf("debería caer a la puerta del servidor: %v", err)
	}
	if enlace != "https://api.arcod.xyz/v2/stream/play?t=v1.abc" {
		t.Fatalf("enlace mal devuelto: %q", enlace)
	}
	// La primera vez se prueba la puerta pública (que acá está cerrada) y luego
	// la del servidor del repo.
	if n := conteo("/api/player/stream/312055179"); n != 1 {
		t.Fatalf("debería probar la puerta pública una vez: %d", n)
	}
	if n := conteo("/v2/stream/312055179"); n != 1 {
		t.Fatalf("debería pedir el stream por la puerta del servidor: %d", n)
	}

	// Segunda resolución: el id del ISRC ya está memorizado y la puerta también,
	// así que la pública NO se vuelve a probar.
	if _, err := cliente.resolverArcod(isrcPrueba, "FLAC"); err != nil {
		t.Fatalf("segunda resolución: %v", err)
	}
	if n := conteo("/api/player/stream/312055179"); n != 1 {
		t.Fatalf("la puerta cerrada no debería volver a probarse: %d", n)
	}
	if n := conteo("/v2/stream/312055179"); n != 2 {
		t.Fatalf("la puerta buena debería usarse de nuevo: %d", n)
	}
}

func TestCanalArcodRechazaLaRutaLegacyParaSinPerdida(t *testing.T) {
	// Solo queda la ruta legacy, que en el repo entrega MP3 320 a la fuerza.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/api/v2/guest/rate-limit":
			_, _ = w.Write([]byte(`{"remaining":999999,"isLimited":false}`))
		case r.URL.Path == "/api/get-music":
			_, _ = w.Write([]byte(jsonCatalogoArcod))
		case r.URL.Path == "/api/get-track-url":
			_, _ = w.Write([]byte(`{"success":true,"url":"https://api.arcod.xyz/v2/stream/play?t=v1.mp3"}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer srv.Close()

	cliente := clienteArcod(srv)
	if _, err := cliente.resolverArcod(isrcPrueba, "FLAC"); err == nil {
		t.Fatal("un pedido sin pérdida no puede aceptar el MP3 de la ruta legacy")
	}
	// El mismo enlace SÍ sirve cuando el usuario pidió pérdida.
	cliente.olvidarPuertaArcod()
	enlace, err := cliente.resolverArcod("QMFMF2447055", "MP3_320")
	if err != nil {
		t.Fatalf("un pedido con pérdida sí puede usar la ruta legacy: %v", err)
	}
	if !strings.Contains(enlace, "v1.mp3") {
		t.Fatalf("enlace inesperado: %q", enlace)
	}
}

func TestCambiarDeInstanciaOlvidaLaPuerta(t *testing.T) {
	cliente := NewClient()
	cliente.recordarPuertaArcod("servidor")
	cliente.aplicarAjusteArcod(map[string]string{"arcod": arcodPropio})
	if got := cliente.puertaArcodGuardada(); got != "" {
		t.Fatalf("otra instancia no puede heredar la puerta de la anterior: %q", got)
	}
}
