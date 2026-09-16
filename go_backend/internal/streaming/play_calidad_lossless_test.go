// play_calidad_lossless_test.go — la calidad pedida manda en la carrera.
//
// Regla que se fija acá: yt-dlp (YouTube) es el FALLBACK DIRECTO, no el
// preferido. Cuando el usuario pidió audio SIN PÉRDIDA y una fuente que sí
// puede darlo (Internet Archive, Soulseek, flac-rescue) tiene un match bueno,
// suena ESA — aunque el re-subido lossy haya respondido primero. Y si la fuente
// sin pérdida no llega, el re-subido se sirve igual: una canción sonando es
// mejor que un fallo de reproducción.
package streaming

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func TestVocabularioDeCalidadSinPerdida(t *testing.T) {
	lossless := []string{"flac", "FLAC", "hifi", "HI_RES_LOSSLESS", "hi_res", "lossless"}
	for _, q := range lossless {
		if !calidadPideLossless(q) {
			t.Errorf("calidadPideLossless(%q) = false, debería ser true", q)
		}
	}
	// El vocabulario real de la app: ['flac','hifi','high','medium','low'].
	lossy := []string{"high", "medium", "low", "mp3", "320", "128", "", "  "}
	for _, q := range lossy {
		if calidadPideLossless(q) {
			t.Errorf("calidadPideLossless(%q) = true, debería ser false", q)
		}
	}
}

// Internet Archive, Soulseek y flac-rescue entregan FLAC real y sin sesión: eso
// es CAPACIDAD de audio (habilita las descargas) y no depende de que puedan
// streamear. YouTube no puede entregar sin pérdida.
func TestClasificacionDeFuentesSinPerdida(t *testing.T) {
	for _, n := range []string{"internetarchive", "soulseek", "flac-rescue"} {
		if !esProveedorLossless(n) {
			t.Errorf("%q debería poder entregar sin pérdida", n)
		}
	}
	// La gracia solo la dan las que pueden entregar EN VIVO.
	for _, n := range []string{"internetarchive", "flac-rescue"} {
		if !esFuenteLosslessSiempre(n) {
			t.Errorf("%q no depende de suscripción para dar sin pérdida", n)
		}
	}
	if esFuenteLosslessSiempre("soulseek") {
		t.Error("soulseek no puede entregar en vivo: no debe dar la gracia de pérdida")
	}
	for _, n := range []string{"youtube", "ytmusic-spotiflac", "soundcloud"} {
		if esProveedorLossless(n) {
			t.Errorf("%q no puede entregar sin pérdida", n)
		}
		if !esProveedorReSubido(n) {
			t.Errorf("%q identifica por nombre y debe esperar a las exactas", n)
		}
	}
	// Soulseek tiene que estar FUERA de las fuentes de AUDIO (no entrega ni un
	// byte por stream) y declarado como fuente de solo descarga, no borrado en
	// silencio. En streamingProviders (metadata) sí va: ahí aporta búsqueda.
	if contieneNombre(proveedoresAudio, "soulseek") {
		t.Fatal("soulseek volvió a la carrera de audio: no puede servir un stream")
	}
	if !esProveedorSoloDescarga("soulseek") {
		t.Fatal("soulseek debe declararse en proveedoresSoloDescarga")
	}
	if !contieneNombre(streamingProviders, "soulseek") {
		t.Fatal("soulseek debe seguir buscando en metadata (streamingProviders)")
	}
}

// sinkLento mantiene la carrera viva sin competir: devuelve vacío y termina
// después de los demás. Evita que el cierre de la carrera pise el orden de
// llegada de las fuentes que sí responden (sin él, el test sería una moneda al
// aire entre "llegó el FLAC" y "ya terminaron todos").
func sinkLento(reg *provider.Registry, espera time.Duration) {
	reg.Register(&verifStubProvider{name: "fuenteexacta_lenta", resolve: func() (string, error) {
		time.Sleep(espera)
		return "", nil
	}})
}

// El caso del usuario: YouTube contesta al instante (lossy) y Internet Archive
// tarda un poco más con FLAC real. Con calidad sin pérdida pedida, gana el FLAC.
func TestConFlacGanaLaFuenteLosslessAunqueLlegueTarde(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&verifStubProvider{name: "youtube", resolve: func() (string, error) {
		return "http://youtube/resubido-lossy", nil
	}})
	reg.Register(&verifStubProvider{name: "internetarchive", resolve: func() (string, error) {
		time.Sleep(250 * time.Millisecond)
		return "http://internetarchive/flac-real", nil
	}})
	sinkLento(reg, 900*time.Millisecond)

	url, name, verified := carreraPorConfianzaCalidad(reg,
		[]string{"youtube", "internetarchive", "fuenteexacta_lenta"}, 5*time.Second, 3,
		func(n string, p provider.Provider) (string, bool) {
			u, err := p.GetStreamURL(n, "flac")
			if err != nil || u == "" {
				return "", false
			}
			return u, false
		}, "flac")

	if verified {
		t.Fatal("no debería pedir verificación de sesión")
	}
	if name != "internetarchive" || url != "http://internetarchive/flac-real" {
		t.Fatalf("con FLAC pedido debe ganar la fuente sin pérdida; ganó %q (%s)", name, url)
	}
}

// Sin calidad sin pérdida pedida, el re-subido rápido sigue ganando: la
// preferencia por FLAC no puede ralentizar una reproducción normal.
func TestSinCalidadLosslessGanaElPrimeroQueResponde(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&verifStubProvider{name: "youtube", resolve: func() (string, error) {
		return "http://youtube/resubido", nil
	}})
	reg.Register(&verifStubProvider{name: "internetarchive", resolve: func() (string, error) {
		time.Sleep(250 * time.Millisecond)
		return "http://internetarchive/flac-real", nil
	}})
	sinkLento(reg, 900*time.Millisecond)

	url, name, _ := carreraPorConfianzaCalidad(reg,
		[]string{"youtube", "internetarchive", "fuenteexacta_lenta"}, 5*time.Second, 3,
		func(n string, p provider.Provider) (string, bool) {
			u, err := p.GetStreamURL(n, "high")
			if err != nil || u == "" {
				return "", false
			}
			return u, false
		}, "high")

	if name != "youtube" || url != "http://youtube/resubido" {
		t.Fatalf("con calidad lossy debe ganar el más rápido; ganó %q (%s)", name, url)
	}
}

// Si la fuente sin pérdida no llega, el fallback se sirve igual: la gracia
// acota la espera y la reproducción nunca queda muda.
func TestConFlacNoSePierdeElFallback(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&verifStubProvider{name: "youtube", resolve: func() (string, error) {
		return "http://youtube/resubido", nil
	}})
	// Internet Archive está registrado pero no encuentra nada para esta pista.
	reg.Register(&verifStubProvider{name: "internetarchive", resolve: func() (string, error) {
		time.Sleep(100 * time.Millisecond)
		return "", nil
	}})
	sinkLento(reg, 700*time.Millisecond)

	url, name, _ := carreraPorConfianzaCalidad(reg,
		[]string{"youtube", "internetarchive", "fuenteexacta_lenta"}, 5*time.Second, 3,
		func(n string, p provider.Provider) (string, bool) {
			u, err := p.GetStreamURL(n, "flac")
			if err != nil || u == "" {
				return "", false
			}
			return u, false
		}, "flac")

	if name != "youtube" || url != "http://youtube/resubido" {
		t.Fatalf("sin FLAC disponible hay que servir el fallback; se sirvió %q (%s)", name, url)
	}
}

// La gracia sin pérdida es más larga que la de identidad (la fuente que da FLAC
// tarda más), pero sigue acotada.
func TestGraciaLosslessAcotadaYMayorQueLaExacta(t *testing.T) {
	if graceLossless <= graceExactos {
		t.Fatalf("graceLossless (%v) debe ser mayor que graceExactos (%v)", graceLossless, graceExactos)
	}
	if graceLossless > 10*time.Second {
		t.Fatalf("graceLossless (%v) no puede comerse el presupuesto de la fase", graceLossless)
	}
	if politicaConfianza("flac").graciaEfectiva() != graceLossless {
		t.Fatal("con calidad sin pérdida la política debe usar graceLossless")
	}
	if politicaConfianza("high").graciaEfectiva() != graceExactos {
		t.Fatal("con calidad lossy la política debe usar graceExactos")
	}
}
