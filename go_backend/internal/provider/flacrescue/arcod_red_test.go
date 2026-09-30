package flacrescue

import (
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"
)

// arcod_red_test.go — Prueba CONTRA EL SITIO REAL, apagada por defecto.
//
// Por qué: los tests con servidor de prueba fijan el flujo (rápido, sin red),
// pero no comprueban lo único que este canal aporta de verdad: que el enlace
// entregue un FLAC del catálogo, y que soporte Range (sin Range no se puede
// reproducir sin bajar la canción entera antes).
//
// Se activa a mano cuando se quiere comprobar el canal:
//
//	BITLY_ARCORD_RED=1 go test ./internal/provider/flacrescue/ -run TestArcodReal -v
//
// No corre en la batería normal ni en los workflows: depende de un tercero.
// Un sitio caído deja la prueba saltada; lo que sí falla es un enlace que se
// resuelve y no entrega FLAC.
func TestArcodRealEntregaUnFLACConRange(t *testing.T) {
	if os.Getenv("BITLY_ARCORD_RED") == "" {
		t.Skip("define BITLY_ARCORD_RED=1 para probar el canal real")
	}
	// Dos canciones distintas del mismo álbum: una sola probaría que el canal
	// funciona para ESE id, no que el catálogo resuelva por ISRC.
	canciones := []struct{ isrc, titulo string }{
		{"QMFMF2447055", "NUEVAYoL"},
		{"QMFMF2447070", "DtMF"},
	}
	for _, cancion := range canciones {
		cancion := cancion
		t.Run(cancion.titulo, func(t *testing.T) {
			cliente := NewClient()
			// Los tests del paquete apagan el canal en TestMain (offline por
			// contrato): el que lo prueba de verdad lo enciende a mano.
			cliente.arcodActivo = true
			enlace, origen, err := cliente.resolverPorISRC(cancion.isrc, []string{"FLAC"}, "")
			if err != nil {
				// Un sitio caído no puede romper la batería: se informa.
				t.Skipf("el canal no resolvió (%v)", err)
			}
			t.Logf("canal %s: %.70s…", origen, enlace)
			if !strings.HasPrefix(enlace, "https://") {
				t.Fatalf("el enlace no es reproducible: %q", enlace)
			}

			// Range: el reproductor necesita poder pedir un tramo, no el
			// archivo entero.
			req, err := http.NewRequest(http.MethodGet, enlace, nil)
			if err != nil {
				t.Fatalf("no se pudo armar la petición: %v", err)
			}
			req.Header.Set("Range", "bytes=0-3")
			resp, err := (&http.Client{Timeout: 40 * time.Second}).Do(req)
			if err != nil {
				t.Fatalf("no se pudo abrir el enlace: %v", err)
			}
			defer resp.Body.Close()
			if resp.StatusCode != http.StatusPartialContent {
				t.Fatalf("el enlace no soporta Range: status %d", resp.StatusCode)
			}
			cabecera := make([]byte, 4)
			if _, err := io.ReadFull(resp.Body, cabecera); err != nil {
				t.Fatalf("no se pudo leer la cabecera: %v", err)
			}
			if string(cabecera) != "fLaC" {
				t.Fatalf("el enlace no entrega FLAC (content-type %q, cabecera %q)",
					resp.Header.Get("Content-Type"), cabecera)
			}
			t.Logf("FLAC con Range ok (content-type %q)", resp.Header.Get("Content-Type"))
		})
	}
}
