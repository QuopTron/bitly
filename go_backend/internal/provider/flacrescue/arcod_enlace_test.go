package flacrescue

// arcod_enlace_test.go — Fija el control del ENLACE del canal arcod: un enlace
// que no sirve audio (el CDN contestando 502, medido en vivo) no puede
// entregarse al reproductor ni quedar cacheado.
//
// Por qué existe: el síntoma era "la canción no reproduce" al tocar un tema
// desde una fuente que cae en el rescate (el caso medido: el feed de Amazon).
// El canal resolvía el ISRC, pedía el enlace, recibía uno que contestaba 502 y
// lo devolvía igual: el reproductor recibía una URL muerta en vez de seguir con
// las otras fuentes.
//
// Nunca sale a Internet: el servidor de prueba hace de CDN.

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestEnlaceArcodSirveAudio(t *testing.T) {
	casos := []struct {
		nombre string
		status int
		quiero string // "ok" o "error"
	}{
		{"200 sirve audio", http.StatusOK, "ok"},
		{"206 (Range) sirve audio", http.StatusPartialContent, "ok"},
		{"502 del CDN no sirve", http.StatusBadGateway, "error"},
		{"403 de un enlace vencido no sirve", http.StatusForbidden, "error"},
		{"404 no sirve", http.StatusNotFound, "error"},
	}
	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if got := r.Header.Get("Range"); got != "bytes=0-0" {
					t.Errorf("la comprobación debe pedir un solo byte, pidió %q", got)
				}
				w.WriteHeader(c.status)
			}))
			defer srv.Close()

			err := enlaceArcodSirveAudio(srv.URL+"/v2/stream/play?t=v1.abc",
				time.Now().Add(time.Second))
			if c.quiero == "ok" && err != nil {
				t.Fatalf("debería aceptar el enlace: %v", err)
			}
			if c.quiero == "error" && err == nil {
				t.Fatal("debería rechazar el enlace")
			}
		})
	}
}

func TestEnlaceArcodFalloDeRedNoInvalida(t *testing.T) {
	// Un fallo de RED al comprobar (no una respuesta de error) no invalida el
	// enlace: puede ser ruido del sondeo y el reproductor es el que decide.
	if err := enlaceArcodSirveAudio("http://127.0.0.1:1/abc.flac", time.Now().Add(time.Second)); err != nil {
		t.Fatalf("un puerto cerrado no debería invalidar el enlace: %v", err)
	}
}

func TestPuertaArcodNoEntregaUnEnlaceRoto(t *testing.T) {
	// El servidor de las puertas responde bien, pero el ENLACE que devuelve
	// está roto (502): el canal tiene que fallar en vez de entregarlo.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/api/v2/guest/rate-limit":
			_, _ = w.Write([]byte(`{"remaining":999999,"isLimited":false}`))
		case r.URL.Path == "/api/get-music":
			_, _ = w.Write([]byte(jsonCatalogoArcod))
		case strings.HasPrefix(r.URL.Path, "/v2/stream/"):
			_, _ = w.Write([]byte(jsonStreamArcod))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer srv.Close()

	anterior := comprobarEnlaceArcod
	comprobarEnlaceArcod = func(string, time.Time) error {
		return errors.New("el enlace no sirve audio (502)")
	}
	t.Cleanup(func() { comprobarEnlaceArcod = anterior })

	cliente := clienteArcod(srv)
	if _, err := cliente.resolverArcod(isrcPrueba, "FLAC"); err == nil {
		t.Fatal("no puede entregar un enlace que no sirve audio")
	}
}
