package streaming

// rescue_identificadores_test.go — Fija el CORTE TEMPRANO de la fase de
// identificadores (ver carreraIdentificadores).
//
// Qué se prueba y por qué con estos números:
//   · la fase termina apenas las fuentes que resuelven por identidad dijeron que
//     no (y se le dio su ventana a los re-subidos): medido en el tap real, esa
//     fase quemaba sus 5 s completos sin stream y recién después arrancaba la
//     búsqueda por nombre, que resolvía en ~3 s;
//   · y NO corta antes de que un re-subido que está por responder alcance a
//     ganar: los que ganaron en esa fase lo hicieron en 1,4-2,0 s, así que la
//     ventana (2,5 s) tiene que dejarlos pasar;
//   · y el corte es SOLO de esa fase: la carrera del rescate conserva su
//     comportamiento (espera el presupuesto), que es lo que ya estaba medido y
//     ajustado.
//
// Todo offline: los proveedores son stubs.

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// intentoStub es el cuerpo de intento de los tests: pide el stream al stub.
func intentoStub(_ string, p provider.Provider) (string, bool) {
	u, err := p.GetStreamURL("", "flac")
	if err != nil || u == "" {
		return "", false
	}
	return u, false
}

// TestIdentificadoresCortaCuandoLosExactosTerminaron: el exacto contesta a los
// 250 ms que no tiene nada y el re-subido se queda colgado. La fase tiene que
// terminar en su ventana, NO esperar los 5 s del presupuesto.
func TestIdentificadoresCortaCuandoLosExactosTerminaron(t *testing.T) {
	release := make(chan struct{})
	defer close(release)
	reg := provider.NewRegistry()
	reg.Register(&stubProvider{name: "flac-rescue", resolve: func() (string, error) {
		time.Sleep(250 * time.Millisecond)
		return "", nil
	}})
	reg.Register(&stubProvider{name: "ytmusic-spotiflac", resolve: func() (string, error) {
		<-release // se queda colgado hasta que termine el test
		return "", nil
	}})

	inicio := time.Now()
	url, prov, verified := carreraIdentificadores(reg, []string{"flac-rescue", "ytmusic-spotiflac"}, 5*time.Second, 3, intentoStub, "flac")
	transcurrido := time.Since(inicio)

	if url != "" || prov != "" || verified {
		t.Fatalf("no había stream que encontrar: url=%q prov=%q verified=%v", url, prov, verified)
	}
	if limite := ventanaIdentificadores + 800*time.Millisecond; transcurrido > limite {
		t.Fatalf("la fase cortó en %s; con los exactos terminados debía cortar cerca de %s (no en los 5 s del presupuesto)",
			transcurrido.Round(10*time.Millisecond), ventanaIdentificadores)
	}
	t.Logf("cortó en %s (ventana %s, presupuesto 5s)", transcurrido.Round(10*time.Millisecond), ventanaIdentificadores)
}

// TestIdentificadoresNoCortaAntesDeQueGaneUnReSubido: el re-subido responde
// DENTRO de la ventana. Si el corte se llevara ese stream, la reproducción
// tendría que irse al rescate por nombre y el tap sería más lento, no más
// rápido — que es exactamente el daño que la ventana evita.
func TestIdentificadoresNoCortaAntesDeQueGaneUnReSubido(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&stubProvider{name: "flac-rescue", resolve: func() (string, error) {
		time.Sleep(250 * time.Millisecond)
		return "", nil
	}})
	reg.Register(&stubProvider{name: "ytmusic-spotiflac", resolve: func() (string, error) {
		time.Sleep(ventanaIdentificadores - 500*time.Millisecond)
		return "http://yt/stream", nil
	}})

	url, prov, _ := carreraIdentificadores(reg, []string{"flac-rescue", "ytmusic-spotiflac"}, 5*time.Second, 3, intentoStub, "flac")
	if url != "http://yt/stream" || prov != "ytmusic-spotiflac" {
		t.Fatalf("el corte se llevó un re-subido que sí iba a resolver: url=%q prov=%q", url, prov)
	}
}

// TestRescateNoCorta: la MISMA situación en la carrera del rescate (política sin
// corte) tiene que agotar su presupuesto. Es la garantía de que el corte quedó
// acotado a la fase de identificadores y no cambió la semántica que ya estaba
// medida y ajustada para el rescate.
func TestRescateNoCorta(t *testing.T) {
	release := make(chan struct{})
	defer close(release)
	reg := provider.NewRegistry()
	reg.Register(&stubProvider{name: "flac-rescue", resolve: func() (string, error) {
		time.Sleep(250 * time.Millisecond)
		return "", nil
	}})
	reg.Register(&stubProvider{name: "ytmusic-spotiflac", resolve: func() (string, error) {
		<-release
		return "", nil
	}})

	const presupuesto = 1200 * time.Millisecond
	inicio := time.Now()
	url, prov, _ := carreraPorConfianzaCalidad(reg, []string{"flac-rescue", "ytmusic-spotiflac"}, presupuesto, 3, intentoStub, "flac")
	transcurrido := time.Since(inicio)

	if url != "" || prov != "" {
		t.Fatalf("no había stream que encontrar: url=%q prov=%q", url, prov)
	}
	if transcurrido < presupuesto {
		t.Fatalf("el rescate cortó en %s: sin corteSinMejoras debe esperar su presupuesto (%s)",
			transcurrido.Round(10*time.Millisecond), presupuesto)
	}
}
