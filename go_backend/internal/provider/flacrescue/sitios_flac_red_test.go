package flacrescue

import (
	"io"
	"net/http"
	"os"
	"testing"
	"time"
)

// sitios_flac_red_test.go — Prueba CONTRA LOS SITIOS REALES, apagada por
// defecto.
//
// Por qué: los tests con servidor de prueba fijan el protocolo de cada sitio
// (rápido y sin red), pero no ven que un sitio haya cambiado ni que esté
// caído. Esta prueba recorre los sitios conocidos UNO POR UNO, busca una
// canción real y comprueba que el enlace entregue un FLAC de verdad (firma
// "fLaC" en los primeros bytes).
//
// Se activa a mano cuando se quiere comprobar los sitios:
//
//	BITLY_SITIO_FLAC=1 go test ./internal/provider/flacrescue/ -run TestSitiosReales -v
//
// No corre en la batería normal ni en los workflows: depende de terceros.
// Un sitio que no resuelve se INFORMA pero no rompe la prueba (los sitios se
// caen solos); lo que sí falla es un sitio que devuelve algo que no es FLAC.
func TestSitiosRealesBajanUnFLACVerificado(t *testing.T) {
	if os.Getenv("BITLY_SITIO_FLAC") == "" {
		t.Skip("define BITLY_SITIO_FLAC=1 para probar los sitios reales")
	}
	// "NUEVAYoL" de Bad Bunny: ISRC, título y duración del catálogo.
	for _, sitio := range sitiosConocidos {
		sitio := sitio
		t.Run(sitio.nombre(), func(t *testing.T) {
			cliente := NewClient()
			cliente.sitios = []sitioFLAC{sitio}
			enlace, nombre, err := cliente.ResolverSitioFLAC("QMFMF2447055", "NUEVAYoL", "Bad Bunny", 183000, "FLAC")
			if err != nil {
				t.Logf("⚠ %s no resolvió: %v", sitio.nombre(), err)
				return
			}
			t.Logf("enlace de %s (%s): %.80s…", nombre, sitio.base(), enlace)

			resp, err := (&http.Client{Timeout: 60 * time.Second}).Get(enlace)
			if err != nil {
				t.Fatalf("no se pudo abrir el enlace: %v", err)
			}
			defer resp.Body.Close()
			cabecera := make([]byte, 4)
			if _, err := io.ReadFull(resp.Body, cabecera); err != nil {
				t.Fatalf("no se pudo leer la cabecera: %v", err)
			}
			if string(cabecera) != "fLaC" {
				t.Fatalf("el enlace no entrega FLAC (content-type %q, cabecera %q)",
					resp.Header.Get("Content-Type"), cabecera)
			}
		})
	}
}
