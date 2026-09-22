package core

import (
	"os"
	"runtime/debug"
	"testing"
)

// TestEsLimiteMemoriaMB_EscalaPorGama fija la política adaptativa: el tope del
// heap de Go tiene que crecer con la RAM del equipo, y en gama baja quedar MUY
// por debajo de la RAM total (el proceso convive con Flutter y el sistema, y
// Android mata por RSS antes de la presión global).
func TestEsLimiteMemoriaMB_EscalaPorGama(t *testing.T) {
	casos := []struct {
		totalMB int
		espera  int
	}{
		{1024, 192},  // gama baja de 1 GB
		{2048, 192},  // gama baja típica (2 GB)
		{3072, 256},  // 3 GB
		{4096, 320},  // gama media (4 GB)
		{6144, 448},  // 6 GB
		{8192, 512},  // 8 GB
		{16384, 768}, // tope de gama
	}
	for _, c := range casos {
		if got := esLimiteMemoriaMB(c.totalMB); got != c.espera {
			t.Errorf("esLimiteMemoriaMB(%d) = %d, se esperaba %d", c.totalMB, got, c.espera)
		}
	}
}

// TestEsLimiteMemoriaMB_NuncaSuperaLaMitadDeLaRAM: la garantía que importa es
// que el tope deje aire. Si algún día alguien sube los números "para ir más
// rápido", esto lo detiene: un tope alto no acelera nada y es exactamente el
// bug que tenía el valor fijo de 1024 MiB en un teléfono de 2 GB.
func TestEsLimiteMemoriaMB_NuncaSuperaLaMitadDeLaRAM(t *testing.T) {
	for _, totalMB := range []int{1024, 2048, 3072, 4096, 6144, 8192, 12288, 16384, 32768} {
		limite := esLimiteMemoriaMB(totalMB)
		if limite*2 > totalMB {
			t.Errorf("con %d MB de RAM el tope %d MB deja demasiado poco margen", totalMB, limite)
		}
	}
}

// TestMemoriaAdaptada_SiemprePositiva: sin /proc/meminfo (escritorio) o con un
// archivo raro, tiene que devolver el valor por defecto y nunca 0 (un tope de 0
// haría que el GC corra sin parar).
func TestMemoriaAdaptada_SiemprePositiva(t *testing.T) {
	limite := memoriaAdaptada()
	if limite < limiteMinimoMemoriaMB {
		t.Fatalf("tope demasiado bajo: %d MiB", limite)
	}
	if limite > 1024 {
		t.Fatalf("tope demasiado alto para móvil: %d MiB", limite)
	}
}

// TestAjustarRuntimeMemoria_RespetaElValorDeLaApp: el valor que fija la app
// (FijarLimiteMemoriaMB, que expone Flutter) gana sobre el adaptativo.
func TestAjustarRuntimeMemoria_RespetaElValorDeLaApp(t *testing.T) {
	if os.Getenv("GOMEMLIMIT") != "" {
		t.Skip("GOMEMLIMIT viene del entorno: AjustarRuntimeMemoria no debe pisarlo")
	}
	defer func() {
		// Restaura el estado: el límite y el override son globales.
		FijarLimiteMemoriaMB(0)
		AjustarRuntimeMemoria()
	}()

	FijarLimiteMemoriaMB(256)
	AjustarRuntimeMemoria()

	// SetMemoryLimit(-1) devuelve el límite actual sin cambiarlo.
	actual := debug.SetMemoryLimit(-1)
	esperado := int64(256) << 20
	if actual != esperado {
		t.Fatalf("límite aplicado = %d bytes, se esperaba %d", actual, esperado)
	}
}

// TestAjustarRuntimeMemoria_DefaultCuandoNoHayOverride: sin valor de la app se
// usa el adaptativo (en el escritorio de pruebas, el default).
func TestAjustarRuntimeMemoria_DefaultCuandoNoHayOverride(t *testing.T) {
	if os.Getenv("GOMEMLIMIT") != "" {
		t.Skip("GOMEMLIMIT viene del entorno")
	}
	FijarLimiteMemoriaMB(0)
	AjustarRuntimeMemoria()
	actual := debug.SetMemoryLimit(-1)
	if actual != int64(memoriaAdaptada())<<20 {
		t.Fatalf("límite aplicado = %d, se esperaba el adaptativo %d MiB",
			actual, memoriaAdaptada())
	}
}
