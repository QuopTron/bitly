package download

import (
	"errors"
	"fmt"
	"sync"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// ──────────────────────────────────────────────────────────────────────
// proveedorContador — proveedor que CUENTA cuántas veces le pidieron metadata
// y que puede quedarse colgado dentro de GetTrack hasta que el test lo libera.
// Es lo que permite medir el single-flight: cuántas consultas reales terminan
// pagando N llamadas simultáneas por el mismo track.
// ──────────────────────────────────────────────────────────────────────
type proveedorContador struct {
	proveedorFalso
	mu        sync.Mutex
	llamadas  int
	arrancado chan struct{} // se cierra cuando la primera llamada entra
	liberar   chan struct{} // si no es nil, GetTrack espera su cierre
	res       *provider.TrackResult
	err       error
	unaVez    sync.Once
}

func (p *proveedorContador) GetTrack(id string) (*provider.TrackResult, error) {
	p.mu.Lock()
	p.llamadas++
	p.mu.Unlock()

	if p.arrancado != nil {
		p.unaVez.Do(func() { close(p.arrancado) })
	}
	if p.liberar != nil {
		<-p.liberar
	}
	if p.err != nil {
		return nil, p.err
	}
	if p.res != nil {
		return p.res, nil
	}
	return nil, fmt.Errorf("sin track")
}

func (p *proveedorContador) GetTrackByISRC(id string) (*provider.TrackResult, error) {
	return p.GetTrack(id)
}

func (p *proveedorContador) veces() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.llamadas
}

// limpiarMemoDetalleTest vacía la caché global: las pruebas corren en el mismo
// proceso y con -count=N una entrada de la corrida anterior se comería la
// llamada que la prueba cuenta (o dejaría a un test esperando una señal que ya
// no va a llegar).
func limpiarMemoDetalleTest() {
	memoDetalleMu.Lock()
	memoDetalleOK = map[string]memoDetalleValor{}
	memoDetalleV = map[string]*memoDetalleVuelo{}
	memoDetalleMu.Unlock()
}

// MemoDetalle está APAGADA por defecto en toda la suite (ver main_test.go);
// cada prueba de acá la prende y la vuelve a apagar.
func TestMemoDetalleColapsaPedidosSimultaneos(t *testing.T) {
	MemoDetalle(true)
	defer MemoDetalle(false)
	limpiarMemoDetalleTest()

	p := &proveedorContador{
		proveedorFalso: proveedorFalso{nombre: "memo-cnt"},
		arrancado:      make(chan struct{}),
		liberar:        make(chan struct{}),
		res:            &provider.TrackResult{ID: "memo-1", Title: "T", Artist: "A", ISRC: "ISRC1"},
	}

	var wg sync.WaitGroup
	resultados := make([]*provider.TrackResult, 4)
	errs := make([]error, 4)
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			resultados[i], errs[i] = memoDetalle(p, "memo-cnt", "getTrack", "id-1")
		}(i)
	}

	<-p.arrancado // el líder ya está consultando al proveedor
	close(p.liberar)
	wg.Wait()

	if v := p.veces(); v != 1 {
		t.Fatalf("4 pedidos idénticos simultáneos pagaron %d consultas; se esperaba 1", v)
	}
	for i, r := range resultados {
		if errs[i] != nil || r == nil || r.ID != "memo-1" {
			t.Fatalf("goroutine %d no recibió el resultado compartido: r=%v err=%v", i, r, errs[i])
		}
	}
}

func TestMemoDetalleReutilizaElExitoYNoMezclaClaves(t *testing.T) {
	MemoDetalle(true)
	defer MemoDetalle(false)
	limpiarMemoDetalleTest()

	p := &proveedorContador{
		proveedorFalso: proveedorFalso{nombre: "memo-cache"},
		res:            &provider.TrackResult{ID: "memo-2"},
	}
	for i := 0; i < 2; i++ {
		if _, err := memoDetalle(p, "memo-cache", "getTrack", "id-1"); err != nil {
			t.Fatalf("llamada %d falló: %v", i, err)
		}
	}
	if v := p.veces(); v != 1 {
		t.Fatalf("la segunda lectura del mismo track pagó otra consulta (%d)", v)
	}

	// Otro id y otro método son claves distintas: ahí SÍ hay que consultar.
	if _, err := memoDetalle(p, "memo-cache", "getTrack", "id-2"); err != nil {
		t.Fatal(err)
	}
	if _, err := memoDetalle(p, "memo-cache", "getTrackByISRC", "id-1"); err != nil {
		t.Fatal(err)
	}
	if v := p.veces(); v != 3 {
		t.Fatalf("claves distintas comparten entrada: %d consultas (se esperaban 3)", v)
	}
}

func TestMemoDetalleNoRetieneErrores(t *testing.T) {
	MemoDetalle(true)
	defer MemoDetalle(false)
	limpiarMemoDetalleTest()

	p := &proveedorContador{
		proveedorFalso: proveedorFalso{nombre: "memo-err"},
		err:            errors.New("429 rate limit"),
	}
	for i := 0; i < 3; i++ {
		if _, err := memoDetalle(p, "memo-err", "getTrack", "id-1"); err == nil {
			t.Fatal("se esperaba el error del proveedor")
		}
	}
	// Un fallo (sesión vencida, 429, track retirado) no puede quedarse pegado
	// 60s: el siguiente intento debe volver a tocar al proveedor real.
	if v := p.veces(); v != 3 {
		t.Fatalf("un error quedó guardado en la caché: %d consultas (se esperaban 3)", v)
	}
}

func TestMemoDetalleApagadaConsultaSiempre(t *testing.T) {
	MemoDetalle(false)
	defer MemoDetalle(false)

	p := &proveedorContador{
		proveedorFalso: proveedorFalso{nombre: "memo-off"},
		res:            &provider.TrackResult{ID: "memo-off-1"},
	}
	for i := 0; i < 2; i++ {
		if _, err := memoDetalle(p, "memo-off", "getTrack", "id-1"); err != nil {
			t.Fatal(err)
		}
	}
	if v := p.veces(); v != 2 {
		t.Fatalf("con la caché apagada se esperaban 2 consultas, hubo %d", v)
	}
}

func TestMemoDetalleSinNombreDeProveedorNoComparte(t *testing.T) {
	MemoDetalle(true)
	defer MemoDetalle(false)
	limpiarMemoDetalleTest()

	a := &proveedorContador{
		proveedorFalso: proveedorFalso{nombre: ""},
		res:            &provider.TrackResult{ID: "sin-nombre-a"},
	}
	b := &proveedorContador{
		proveedorFalso: proveedorFalso{nombre: ""},
		res:            &provider.TrackResult{ID: "sin-nombre-b"},
	}
	ra, errA := memoDetalle(a, "", "getTrack", "id-1")
	rb, errB := memoDetalle(b, "", "getTrack", "id-1")
	if errA != nil || errB != nil {
		t.Fatalf("errores inesperados: %v / %v", errA, errB)
	}
	if ra == nil || rb == nil || ra.ID != "sin-nombre-a" || rb.ID != "sin-nombre-b" {
		t.Fatalf("dos proveedores sin nombre compartieron entrada: ra=%v rb=%v", ra, rb)
	}
	if a.veces() != 1 || b.veces() != 1 {
		t.Fatalf("consultas inesperadas: a=%d b=%d", a.veces(), b.veces())
	}
}
