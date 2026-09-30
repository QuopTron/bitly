package download

import (
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// proveedorColgado — proveedor cuya resolución NUNCA termina hasta que el test
// cierra [liberar]. Sirve para reproducir el caso real (una fuente lenta) sin
// depender de la red: el cliente de extensiones aguanta 30s por llamada.
type proveedorColgado struct {
	proveedorFalso
	liberar chan struct{}
}

func (p *proveedorColgado) GetTrack(string) (*provider.TrackResult, error) {
	<-p.liberar
	return nil, fmt.Errorf("resolución colgada")
}

func (p *proveedorColgado) GetTrackByISRC(string) (*provider.TrackResult, error) {
	return p.GetTrack("")
}

// limpiarResCacheTest vacía la caché de resoluciones global: las pruebas corren
// en el mismo proceso y con -count=N la entrada de la corrida anterior
// respondería antes de que el test pueda contar sus propias llamadas (y la
// señal de "ya arrancó" nunca llegaría).
func limpiarResCacheTest() {
	resCacheMu.Lock()
	resCache = map[string]map[string][3]string{}
	resCacheOrder = nil
	resVuelo = map[string]*vueloResolucion{}
	resCacheMu.Unlock()
}

// ──────────────────────────────────────────────────────────────────────
// Resolución: single-flight por (proveedor, identidad).
// ──────────────────────────────────────────────────────────────────────
func TestResolucionCacheadaPagaUnaSolaConsulta(t *testing.T) {
	limpiarResCacheTest()
	clave := "vuelo-res-" + t.Name()
	p := &proveedorContador{
		proveedorFalso: proveedorFalso{nombre: "vuelo-res"},
		arrancado:      make(chan struct{}),
		liberar:        make(chan struct{}),
		res:            &provider.TrackResult{ID: "vuelo-id", Title: "T", Artist: "A"},
	}
	// name != req.Provider → la resolución va por el cruce de ids y sí llama a
	// GetTrack (el camino del dueño devuelve el TrackID sin consultar nada).
	req := Request{Provider: "otro", DeezerID: "dz-1"}

	var wg sync.WaitGroup
	ids := make([]string, 3)
	for i := 0; i < 3; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			ids[i], _, _ = resolucionCacheada(p, "vuelo-res", clave, req)
		}(i)
	}

	<-p.arrancado
	close(p.liberar)
	wg.Wait()

	if v := p.veces(); v != 1 {
		t.Fatalf("3 resoluciones simultáneas pagaron %d consultas; se esperaba 1", v)
	}
	for i, id := range ids {
		if id != "vuelo-id" {
			t.Fatalf("goroutine %d resolvió %q, se esperaba \"vuelo-id\"", i, id)
		}
	}
}

// ──────────────────────────────────────────────────────────────────────
// warmResolveAndOrder: lanzar candidatos no puede retener la descarga.
//
// El turno del semáforo (3 en vuelo) se toma DENTRO de cada goroutine: tomado en
// el lanzador, con más candidatos que turnos la función no retornaba hasta que
// N-3 resoluciones terminaran, así que una sola fuente lenta retenía la
// descarga entera ANTES de que corriera la ventana de la carrera.
// ──────────────────────────────────────────────────────────────────────
func TestWarmResolveNoEsperaALasResolucionesColgadas(t *testing.T) {
	limpiarResCacheTest()
	liberar := make(chan struct{})
	defer close(liberar)

	pref := &proveedorFalso{nombre: "warm-pref"}
	reg := provider.NewRegistry()
	reg.Register(pref)

	nombres := []string{"warm-pref"}
	for i := 0; i < 5; i++ {
		n := fmt.Sprintf("warm-colgado-%d", i)
		reg.Register(&proveedorColgado{
			proveedorFalso: proveedorFalso{nombre: n},
			liberar:        liberar,
		})
		nombres = append(nombres, n)
	}
	o := NewOrchestrator(reg)

	// El preferido es el DUEÑO del track: resuelve al instante, sin red.
	req := Request{Provider: "warm-pref", TrackID: "warm-t1", Title: "T", Artist: "A"}
	listo := make(chan []string, 1)
	go func() {
		listo <- o.warmResolveAndOrder(nombres, req, "warm-key-"+t.Name())
	}()

	select {
	case orden := <-listo:
		if len(orden) != len(nombres) {
			t.Fatalf("el orden perdió candidatos: %d de %d", len(orden), len(nombres))
		}
		if orden[0] != "warm-pref" {
			t.Fatalf("el proveedor preferido debe ir primero: %v", orden)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("warmResolveAndOrder quedó retenido por las resoluciones colgadas: " +
			"el turno del semáforo se está tomando en el lanzador")
	}
}

// providersToTry trae al proveedor preferido DOS veces (prependido a un
// fallbackOrder que ya lo contiene): no deben gastarse dos turnos del semáforo
// ni repetirse en el orden final.
func TestWarmResolveNoRepiteCandidatos(t *testing.T) {
	limpiarResCacheTest()
	p := &proveedorContador{
		proveedorFalso: proveedorFalso{nombre: "warm-dup"},
		res:            &provider.TrackResult{ID: "warm-dup-id"},
	}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	// name != req.Provider → resuelve por cruce de ids (llama a GetTrack).
	req := Request{Provider: "otro", DeezerID: "dz-dup"}
	orden := o.warmResolveAndOrder([]string{"warm-dup", "warm-dup"}, req, "warm-dup-"+t.Name())

	if len(orden) != 1 || orden[0] != "warm-dup" {
		t.Fatalf("el candidato duplicado no se colapsó: %v", orden)
	}
	// El single-flight también colapsa las dos resoluciones simultáneas, así
	// que la consulta real es una sola.
	if v := p.veces(); v != 1 {
		t.Fatalf("el candidato duplicado se resolvió %d veces", v)
	}
}
