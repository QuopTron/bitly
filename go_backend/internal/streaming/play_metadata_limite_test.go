package streaming

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// buscadorStub es un proveedor con latencia y resultados controlados: sirve
// para probar los presupuestos y la cosecha en paralelo sin red.
type buscadorStub struct {
	*stubProvider
	espera time.Duration
	track  *provider.TrackResult
}

func (b *buscadorStub) SearchTracks(_ string, _ int) ([]provider.TrackResult, error) {
	if b.espera > 0 {
		time.Sleep(b.espera)
	}
	if b.track == nil {
		return nil, nil
	}
	return []provider.TrackResult{*b.track}, nil
}

func (b *buscadorStub) GetTrackByISRC(_ string) (*provider.TrackResult, error) {
	if b.espera > 0 {
		time.Sleep(b.espera)
	}
	return b.track, nil
}

func nuevoBuscador(nombre string, espera time.Duration, id string) *buscadorStub {
	return &buscadorStub{
		stubProvider: &stubProvider{name: nombre},
		espera:       espera,
		track:        &provider.TrackResult{ID: id, Title: id},
	}
}

// El presupuesto es una mejora, no un corte: si el proveedor responde dentro de
// la ventana, su resultado se usa tal cual.
func TestResolverConPresupuestoUsaElResultadoATiempo(t *testing.T) {
	esperado := &provider.TrackResult{ID: "ok"}
	got := resolverConPresupuesto(500*time.Millisecond, func() *provider.TrackResult {
		time.Sleep(10 * time.Millisecond)
		return esperado
	})
	if got != esperado {
		t.Fatalf("se esperaba el resultado a tiempo, llegó %v", got)
	}
}

// Y si se cuelga, la reproducción NO lo espera: devuelve nil dentro del
// presupuesto (medido: una extensión se quedó 65s en una sola llamada).
func TestResolverConPresupuestoCortaAlLento(t *testing.T) {
	inicio := time.Now()
	got := resolverConPresupuesto(80*time.Millisecond, func() *provider.TrackResult {
		time.Sleep(2 * time.Second)
		return &provider.TrackResult{ID: "tarde"}
	})
	transcurrido := time.Since(inicio)
	if got != nil {
		t.Fatalf("un proveedor colgado no puede aportar metadata: %v", got)
	}
	if transcurrido > 500*time.Millisecond {
		t.Fatalf("el corte tardó %s, el presupuesto era 80ms", transcurrido)
	}
}

// La búsqueda paralela respeta la PREFERENCIA de orden: un proveedor que va
// antes en la lista y llega dentro de la ventana le gana a uno más rápido.
func TestBuscarEnParaleloRespetaElOrden(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(nuevoBuscador("preferido", 60*time.Millisecond, "preferido"))
	reg.Register(nuevoBuscador("rapido", 5*time.Millisecond, "rapido"))

	got := buscarEnParalelo(reg, []string{"preferido", "rapido"}, "", time.Second,
		func(p provider.Provider, _ string) *provider.TrackResult {
			res, _ := p.SearchTracks("q", 8)
			if len(res) == 0 {
				return nil
			}
			return &res[0]
		})
	if got == nil || got.ID != "preferido" {
		t.Fatalf("se esperaba el proveedor preferido, llegó %v", got)
	}
}

// Sin nadie que responda, la fase termina en el presupuesto y devuelve nil: la
// metadata es opcional y no puede retener la reproducción.
func TestBuscarEnParaleloCortaAlPresupuesto(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(nuevoBuscador("mudo", 2*time.Second, "tarde"))

	inicio := time.Now()
	got := buscarEnParalelo(reg, []string{"mudo"}, "", 100*time.Millisecond,
		func(p provider.Provider, _ string) *provider.TrackResult {
			res, _ := p.SearchTracks("q", 8)
			if len(res) == 0 {
				return nil
			}
			return &res[0]
		})
	if got != nil {
		t.Fatalf("se esperaba nil, llegó %v", got)
	}
	if transcurrido := time.Since(inicio); transcurrido > 600*time.Millisecond {
		t.Fatalf("la búsqueda paralela tardó %s con presupuesto de 100ms", transcurrido)
	}
}

// El proveedor preferido ya se consultó aparte: no puede repetirse acá.
func TestBuscarEnParaleloRespetaElExcluido(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(nuevoBuscador("preferido", 0, "preferido"))

	got := buscarEnParalelo(reg, []string{"preferido", "otro"}, "preferido",
		200*time.Millisecond, func(p provider.Provider, _ string) *provider.TrackResult {
			res, _ := p.SearchTracks("q", 8)
			if len(res) == 0 {
				return nil
			}
			return &res[0]
		})
	if got != nil {
		t.Fatalf("el proveedor preferido no debe re-consultarse: %v", got)
	}
}
