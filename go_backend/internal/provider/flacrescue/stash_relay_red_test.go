package flacrescue

// stash_relay_red_test.go — Medición CONTRA EL RELAY REAL del canal
// stash-relay. Se activa a mano porque depende de un tercero:
//
//	BITLY_STASH_RED=1 go test ./internal/provider/flacrescue/ -run TestRedStashRelay -v
//
// Mide lo que importa: que el mint devuelva un enlace y que ese enlace entregue
// FLAC de verdad, con Range y del tamaño de una canción (no una muestra).

import (
	"os"
	"strings"
	"testing"
	"time"
)

func TestRedStashRelay(t *testing.T) {
	if os.Getenv("BITLY_STASH_RED") == "" {
		t.Skip("define BITLY_STASH_RED=1 para medir el relay real")
	}
	// TestMain apaga el canal (los tests del paquete son offline por contrato).
	cliente := NewClient()
	cliente.stashActivo = true
	cliente.stashConfigURL = "" // config de fábrica del proyecto Stash

	inicio := time.Now()
	// Un id de pista NUMÉRICO: resuelve el mint sin necesitar el catálogo de
	// Qobuz, que es lo que se quiere medir acá.
	enlace, err := cliente.resolverStashRelay(trackStashPrueba, "FLAC")
	if err != nil {
		t.Fatalf("el relay no resolvió: %v", err)
	}
	if !strings.HasPrefix(enlace, "https://") {
		t.Fatalf("el enlace no es reproducible: %q", enlace)
	}
	tipo, total := pideTramo(t, enlace)
	t.Logf("stash-relay en %dms: content-type=%q, %d bytes (%.1f MB) — Range ok",
		time.Since(inicio).Milliseconds(), tipo, total, float64(total)/1024/1024)
	if total > 0 && total < 8<<20 {
		t.Fatalf("el archivo es sospechosamente corto (%d bytes): ¿es una muestra?", total)
	}
}
