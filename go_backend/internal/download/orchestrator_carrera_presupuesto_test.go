package download

import (
	"fmt"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// TestFalloTodosLosCandidatosNoEsperaElPresupuesto fija que una carrera
// condenada a fallar devuelva el error ENSEGUIDA.
//
// El bug que evita: el bucle de la carrera solo comprobaba "¿ya no queda nada en
// vuelo?" al recibir un evento `sinMas`. Cuando el ÚLTIMO evento era un fallo de
// proveedor (que es lo que pasa cuando la fuente dueña falla y el feeder ya se
// quedó sin candidatos), el bucle quedaba bloqueado en el `select` esperando un
// evento que nunca iba a llegar, y recién despertaba al agotarse el presupuesto
// (50 s). En el celular eso se ve como "la descarga se queda pensando y después
// dice que falló"; en CI hacía que el paquete se pasara del timeout de 180 s.
func TestFalloTodosLosCandidatosNoEsperaElPresupuesto(t *testing.T) {
	fallo := &proveedorFalso{nombre: "int-pres-f1", streamErr: fmt.Errorf("sin stream")}
	reg := provider.NewRegistry()
	reg.Register(fallo)
	o := NewOrchestrator(reg)

	inicio := time.Now()
	res := o.Download(Request{
		ItemID:    "int_presupuesto_1",
		Provider:  "int-pres-f1",
		TrackID:   "pres-id-1",
		OutputDir: t.TempDir(),
	})
	tardanza := time.Since(inicio)

	if res == nil || res.Success {
		t.Fatalf("la descarga debía fallar, devolvió %+v", res)
	}
	// El presupuesto real es de 50 s: si se vuelve a dormir hasta agotarlo, el
	// test lo caza. El margen es amplio para no depender de la velocidad del
	// runner, pero muy por debajo del presupuesto.
	if tardanza > 10*time.Second {
		t.Fatalf("tardó %s en reportar el fallo: la carrera se quedó esperando el presupuesto", tardanza)
	}
	t.Logf("OK: falló en %s con %q", tardanza.Round(time.Millisecond), res.Error)
}
