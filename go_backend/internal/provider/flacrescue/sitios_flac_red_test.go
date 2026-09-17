package flacrescue

import (
	"io"
	"net/http"
	"os"
	"testing"
	"time"
)

// sitios_flac_red_test.go — Prueba CONTRA EL SITIO REAL, apagada por defecto.
//
// Por qué: sitios_flac_test.go fija el protocolo con un servidor de prueba
// (rápido, sin red), pero un cambio del sitio no se ve ahí. Esta prueba
// comprueba el flujo vivo: buscar por ISRC, verificar el match y confirmar que
// el enlace entrega un FLAC de verdad (firma "fLaC" en los primeros bytes).
//
// Se activa a mano cuando se quiere comprobar el sitio:
//
//	BITLY_SITIO_FLAC=1 go test ./internal/provider/flacrescue/ -run TestSitioReal -v
//
// No corre en la batería normal ni en los workflows: depende de un tercero.
func TestSitioRealBajaUnFLACVerificado(t *testing.T) {
	if os.Getenv("BITLY_SITIO_FLAC") == "" {
		t.Skip("define BITLY_SITIO_FLAC=1 para probar el sitio real")
	}
	cliente := NewClient()
	// "NUEVAYoL" de Bad Bunny: ISRC y duración del catálogo.
	enlace, sitio, err := cliente.ResolverSitioFLAC("QMFMF2447055", "NUEVAYoL", "Bad Bunny", 183000, "FLAC")
	if err != nil {
		t.Fatalf("el sitio no resolvió: %v", err)
	}
	t.Logf("enlace de %s: %.80s…", sitio, enlace)

	resp, err := (&http.Client{Timeout: 40 * time.Second}).Get(enlace)
	if err != nil {
		t.Fatalf("no se pudo abrir el enlace: %v", err)
	}
	defer resp.Body.Close()
	if ct := resp.Header.Get("Content-Type"); ct != "audio/flac" {
		t.Fatalf("el enlace no entrega FLAC: %q", ct)
	}
	cabecera := make([]byte, 4)
	if _, err := io.ReadFull(resp.Body, cabecera); err != nil {
		t.Fatalf("no se pudo leer la cabecera: %v", err)
	}
	if string(cabecera) != "fLaC" {
		t.Fatalf("el archivo no es FLAC: %q", cabecera)
	}
}
