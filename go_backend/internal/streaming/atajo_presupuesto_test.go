package streaming

import (
	"strings"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// acortarPresupuestoAtajo deja el techo del atajo en [d] y lo devuelve al
// terminar el test. El presupuesto es un var justamente para esto: un test no
// puede esperar 4 segundos para comprobar que el atajo se corta.
func acortarPresupuestoAtajo(t *testing.T, d time.Duration) {
	t.Helper()
	previo := presupuestoAtajo
	presupuestoAtajo = d
	t.Cleanup(func() { presupuestoAtajo = previo })
}

// lentoSinStream es un proveedor que tarda [porLlamada] por GetStreamURL y no
// devuelve stream: es el caso de un provider colgado en la firma de su sesión.
// Devuelve URL vacía y sin error a propósito, para que el bucle siga con la
// siguiente calidad sin enfriar al proveedor (cooldown) y el corte se deba
// SOLO al presupuesto.
func lentoSinStream(nombre string, porLlamada time.Duration, llamadas *int) *stubProvider {
	return &stubProvider{name: nombre, resolve: func() (string, error) {
		*llamadas++
		time.Sleep(porLlamada)
		return "", nil
	}}
}

// TestStreamQuickSeCortaPorPresupuesto es el techo de 1.1: el atajo al proveedor
// preferido no puede estirarse sin límite. Sin este corte, un provider lento
// hacía tantas llamadas de calidad como hicieran falta (hasta 8 en serie, con
// timeouts de 30 s cada uno) y el rescate —que es donde de verdad se gana el
// stream cuando este proveedor no da— ni siquiera arrancaba.
func TestStreamQuickSeCortaPorPresupuesto(t *testing.T) {
	acortarPresupuestoAtajo(t, 150*time.Millisecond)

	llamadas := 0
	reg := provider.NewRegistry()
	reg.Register(lentoSinStream("atajo-lento", 30*time.Millisecond, &llamadas))

	trackID := "algo"
	quality := "high"
	// Sin título: no hay verificación que hacer, así que se mide solo el bucle
	// de calidades, que es lo que este test quiere acotar.
	inicio := time.Now()
	url, prov, err := StreamQuick(reg, "atajo-lento", trackID, quality, "", "", "", "", "", "", "", 0)
	trascurrido := time.Since(inicio)

	if err == nil {
		t.Fatalf("StreamQuick devolvió stream (%q por %s) cuando el presupuesto debía cortarlo", url, prov)
	}
	if !strings.Contains(err.Error(), "presupuesto") {
		t.Errorf("el error debe distinguir el corte por tiempo de un fallo del proveedor, fue: %v", err)
	}
	if trascurrido < presupuestoAtajo {
		t.Errorf("cortó a los %s, antes del presupuesto de %s", trascurrido, presupuestoAtajo)
	}
	// Holgura generosa: el corte se evalúa al ENTRAR en cada vuelta, así que la
	// última llamada puede terminar algo después del techo.
	if exceso := trascurrido - presupuestoAtajo; exceso > 300*time.Millisecond {
		t.Errorf("se pasó %s por encima del presupuesto (total %s)", exceso, trascurrido)
	}
	totales := len(calidadesDisponibles(quality))
	if llamadas == 0 {
		t.Error("no llegó a intentar ninguna calidad")
	}
	if llamadas >= totales {
		t.Errorf("probó las %d calidades completas (%d): el presupuesto no cortó nada", llamadas, totales)
	}
}

// TestAtajoRapidoNoTocaElPresupuesto es la contraparte: un proveedor que
// responde de inmediato no puede verse afectado por el techo. Sin esto, el
// presupuesto sería una forma elegante de romper el camino rápido.
func TestAtajoRapidoNoTocaElPresupuesto(t *testing.T) {
	llamadas := 0
	reg := provider.NewRegistry()
	reg.Register(&verifStubProvider{
		name: "atajo-rapido",
		track: &provider.TrackResult{
			ID: "algo", Title: "titulo", Artist: "artista", Duration: 1000,
		},
		resolve: func() (string, error) {
			llamadas++
			return "http://cdn/rapido.flac", nil
		},
	})

	// Con título: además del bucle, este test pasa por la verificación de
	// identidad — que también consume presupuesto y que NO debe cortarse
	// cuando hay tiempo de sobra.
	url, prov, err := StreamQuick(reg, "atajo-rapido", "algo", "high", "", "", "", "", "", "titulo", "artista", 1000)
	if err != nil {
		t.Fatalf("el atajo rápido falló: %v", err)
	}
	if url == "" || prov != "atajo-rapido" {
		t.Errorf("url=%q prov=%q, se esperaba el stream del proveedor preferido", url, prov)
	}
	if llamadas != 1 {
		t.Errorf("%d llamadas a GetStreamURL, se esperaba 1 (la primera calidad basta)", llamadas)
	}
}

// TestIntentarStreamTambienSeCortaPorPresupuesto cubre el OTRO atajo:
// intentarStream es el que usa GetStreamPackage (atajo propio) y tiene cuatro
// bloques de calidades sin techo — el mismo defecto, en el otro camino.
func TestIntentarStreamTambienSeCortaPorPresupuesto(t *testing.T) {
	acortarPresupuestoAtajo(t, 150*time.Millisecond)

	llamadas := 0
	reg := provider.NewRegistry()
	reg.Register(lentoSinStream("atajo-paquete-lento", 30*time.Millisecond, &llamadas))

	inicio := time.Now()
	url, err := intentarStream(reg, "atajo-paquete-lento", "algo", nil, "high")
	trascurrido := time.Since(inicio)

	if err == nil {
		t.Fatalf("intentarStream devolvió %q cuando el presupuesto debía cortarlo", url)
	}
	if !strings.Contains(err.Error(), "presupuesto") {
		t.Errorf("el error debe distinguir el corte por tiempo, fue: %v", err)
	}
	if trascurrido > presupuestoAtajo+300*time.Millisecond {
		t.Errorf("el atajo duró %s (presupuesto %s)", trascurrido, presupuestoAtajo)
	}
	if llamadas >= len(calidadesDisponibles("high")) {
		t.Errorf("probó las %d calidades completas: el presupuesto no cortó nada", llamadas)
	}
}
