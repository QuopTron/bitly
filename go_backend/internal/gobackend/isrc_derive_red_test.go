package gobackend

// isrc_derive_red_test.go — Medición CONTRA LA RED REAL de la derivación de
// ISRC, que es la lógica que decide qué audio suena cuando la fuente no publica
// ISRC (el caso del feed de Amazon).
//
//	BITLY_ISRC_RED=1 go test ./internal/gobackend/ -run TestRedDerivarISRCBbYWow -v
//
// Mide el caso que rompía: "BbY WOW" de KAROL G, Judeline & rusowsky. El
// catálogo de flacdownloader (Qobuz) devuelve, además del corte real, discos de
// covers que acreditan al artista original en el título
// ("BbY WOW (KAROL G, Judeline, rusowsky)" de Epic Symphonic Orchestra). Con el
// matching viejo ese cover pasaba por original y su ISRC se usaba para resolver
// el audio (la versión de versión). El ISRC correcto es USUG12607940.

import (
	"os"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/flacdownloader"
)

func TestRedDerivarISRCBbYWow(t *testing.T) {
	if os.Getenv("BITLY_ISRC_RED") == "" {
		t.Skip("define BITLY_ISRC_RED=1 para medir la derivación real")
	}
	reg := provider.NewRegistry()
	reg.Register(flacdownloader.NewClient(nil))

	got := provider.DerivarISRC(reg, "BbY WOW", "KAROL G, Judeline & rusowsky", 225000)
	t.Logf("DerivarISRC(BbY WOW / KAROL G, Judeline & rusowsky) = %q", got)
	if got != "USUG12607940" {
		t.Fatalf("se derivó %q: no es el corte real (USUG12607940). Un cover se colaría como original", got)
	}
}
