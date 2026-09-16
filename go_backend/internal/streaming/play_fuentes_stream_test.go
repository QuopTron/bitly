// play_fuentes_stream_test.go — Pincha dos cosas de la CADENA DE REPRODUCCIÓN:
//
//  1. Soulseek NO puede servir un stream (su GetStreamURL no está cableado: el
//     audio se baja peer-to-peer). Si se lo devuelve a la carrera de audio,
//     gasta un turno del pool, hace una búsqueda P2P completa por cada tap y
//     —peor— con calidad sin pérdida entraba como bloqueante, haciendo esperar
//     una gracia por una fuente que no puede entregar ni un byte.
//  2. Un resultado real (YouTube / yt-dlp) no se hace esperar por fuentes que
//     no pueden streamear: si las fuentes sin pérdida contestan "no tengo
//     nada", el audio sale YA (acuse de bloqueantes); si se cuelgan, el tope
//     es la gracia de pérdida (1,8s) y nunca el presupuesto completo.
//
// Run: cd go_backend && go test ./internal/streaming/ -run FuentesStream -v

package streaming

import (
	"errors"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

var errSinStream = errors.New("sin stream")

// nombresDeLaCadena son las fuentes que la app consulta en la vida real.
var nombresDeLaCadena = []string{
	"ytmusic-spotiflac", "youtube", "internetarchive", "flac-rescue",
	"soundcloud", "soulseek",
}

// intentoPorStreamURL es el trabajo de un worker: pedir la URL de audio.
func intentoPorStreamURL(name string, p provider.Provider) (string, bool) {
	u, err := p.GetStreamURL(name, "flac")
	if err != nil || u == "" {
		return "", false
	}
	return u, false
}

// armaRegistry crea la cadena con stubs: YouTube responde a los 250ms y las
// fuentes sin pérdida se comportan según [modo] ("muerta" contesta ya, "colgada"
// nunca contesta). Soulseek queda colgado SIEMPRE: si vuelve a la carrera, el
// test lo delata por tiempo.
func armaRegistry(modo string) (*provider.Registry, chan struct{}) {
	release := make(chan struct{})
	reg := provider.NewRegistry()
	for _, n := range nombresDeLaCadena {
		cooldown.MarkOk(n) // sin cooldown heredado de otro test
	}
	reg.Register(&stubProvider{name: "ytmusic-spotiflac", resolve: func() (string, error) {
		time.Sleep(250 * time.Millisecond)
		return "http://ytmusic/stream", nil
	}})
	for _, n := range []string{"youtube", "soundcloud"} {
		reg.Register(&stubProvider{name: n, resolve: func() (string, error) {
			return "", errSinStream
		}})
	}
	for _, n := range []string{"internetarchive", "flac-rescue"} {
		reg.Register(&stubProvider{name: n, resolve: func() (string, error) {
			if modo == "colgada" {
				<-release
				return "", nil
			}
			return "", errSinStream
		}})
	}
	reg.Register(&stubProvider{name: "soulseek", resolve: func() (string, error) {
		<-release
		return "", nil
	}})
	return reg, release
}

// TestSoulseekSoloDescarga: Soulseek puede BAJAR el FLAC pero no streamearlo,
// así que no debe figurar como fuente de audio ni recibir la gracia de pérdida.
func TestSoulseekSoloDescarga(t *testing.T) {
	if esProviderStreaming("soulseek") {
		t.Fatal("soulseek está en proveedoresAudio y no puede servir un stream")
	}
	if !esProveedorSoloDescarga("soulseek") {
		t.Fatal("soulseek debe declararse en proveedoresSoloDescarga")
	}
	if esFuenteLosslessSiempre("soulseek") {
		t.Fatal("soulseek no debe dar la gracia de pérdida: no entrega audio en vivo")
	}
	if !esProveedorLossless("soulseek") {
		t.Fatal("soulseek debe seguir contando como fuente lossless (para descargas)")
	}
	for _, n := range proveedoresAudio {
		if esProveedorSoloDescarga(n) {
			t.Fatalf("%s figura como fuente de audio Y como fuente de solo descarga", n)
		}
	}
	reg, release := armaRegistry("muerta")
	defer close(release)
	for _, n := range ordenProvidersStreaming(reg) {
		if n == "soulseek" {
			t.Fatal("ordenProvidersStreaming devolvió soulseek: volvió a la carrera de audio")
		}
	}
}

// TestFuentesStreamLosslessNoAgreganEspera: con FLAC pedido y Soulseek
// registrado (colgado), el resultado real suena apenas las fuentes sin pérdida
// dicen "no tengo nada" — y si esas se cuelgan, el tope es la gracia de pérdida,
// nunca los 20s del presupuesto.
func TestFuentesStreamLosslessNoAgreganEspera(t *testing.T) {
	t.Run("fuentes sin pérdida caídas: suena ya", func(t *testing.T) {
		reg, release := armaRegistry("muerta")
		defer close(release)
		names := ordenProvidersStreaming(reg)
		if len(names) < 4 {
			t.Fatalf("la cadena quedó con %d fuentes: %v", len(names), names)
		}
		start := time.Now()
		url, prov, _ := carreraPorConfianzaCalidad(reg, names, 20*time.Second, 4, intentoPorStreamURL, "flac")
		elapsed := time.Since(start)
		if prov != "ytmusic-spotiflac" {
			t.Fatalf("ganó %q (%q), se esperaba el re-subido de YouTube", prov, url)
		}
		if elapsed > graceExactos {
			t.Fatalf("tardó %s: esperó de más por una fuente que no puede streamear", elapsed)
		}
		t.Logf("FLAC pedido, lossless caídas -> %q en %s (sin esperar a soulseek)",
			prov, elapsed.Round(10*time.Millisecond))
	})

	t.Run("fuentes sin pérdida colgadas: tope la gracia", func(t *testing.T) {
		reg, release := armaRegistry("colgada")
		defer close(release)
		names := ordenProvidersStreaming(reg)
		start := time.Now()
		url, prov, _ := carreraPorConfianzaCalidad(reg, names, 20*time.Second, 4, intentoPorStreamURL, "flac")
		elapsed := time.Since(start)
		if prov != "ytmusic-spotiflac" || url == "" {
			t.Fatalf("ganó %q (%q), se esperaba el re-subido de YouTube", prov, url)
		}
		if elapsed > graceLossless+400*time.Millisecond {
			t.Fatalf("tardó %s: se quedó esperando fuentes que no pueden streamear", elapsed)
		}
		t.Logf("FLAC pedido, lossless colgadas -> %q en %s (tope = gracia, no el presupuesto)",
			prov, elapsed.Round(10*time.Millisecond))
	})
}
