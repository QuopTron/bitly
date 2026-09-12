package core

import (
	"sync"
	"testing"
)

// TestStressLimiteMemoriaSinCarreras fuerza el patrón real: Flutter ajusta el
// tope de RAM (SetMemoryLimitMB → FijarLimiteMemoriaMB) en caliente mientras
// AjustarRuntimeMemoria lo lee para aplicarlo al GC. Sin candado, esas dos
// goroutines escriben y leen el mismo int sin sincronizar.
func TestStressLimiteMemoriaSinCarreras(t *testing.T) {
	const valorSeguro = 1024
	defer FijarLimiteMemoriaMB(0)

	const vueltas = 300
	arranque := make(chan struct{})
	var wg sync.WaitGroup

	wg.Add(1)
	go func() {
		defer wg.Done()
		<-arranque
		for i := 0; i < vueltas; i++ {
			FijarLimiteMemoriaMB(valorSeguro)
			FijarLimiteMemoriaMB(0)
		}
	}()

	for r := 0; r < 3; r++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-arranque
			for i := 0; i < vueltas; i++ {
				_ = getLimiteMemoriaMB()
			}
		}()
	}

	close(arranque)
	wg.Wait()

	if got := getLimiteMemoriaMB(); got != 0 {
		t.Fatalf("esperaba el límite restaurado a 0, quedó %d", got)
	}
}

// TestLimiteMemoriaAplicaDefault comprueba que 0/negativo cae al default y un
// valor positivo se respeta — el contrato que usa SetMemoryLimitMB.
func TestLimiteMemoriaAplicaDefault(t *testing.T) {
	defer FijarLimiteMemoriaMB(0)

	FijarLimiteMemoriaMB(2048)
	if got := getLimiteMemoriaMB(); got != 2048 {
		t.Fatalf("esperaba 2048, obtuve %d", got)
	}
	FijarLimiteMemoriaMB(-5)
	if got := getLimiteMemoriaMB(); got != -5 {
		t.Fatalf("esperaba -5 (negativo = default), obtuve %d", got)
	}
}
