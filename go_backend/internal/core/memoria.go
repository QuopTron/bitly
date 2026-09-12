package core

import (
	"log"
	"os"
	"runtime"
	"runtime/debug"
	"sync"
)

// limiteMemoriaMBDefault es el tope blando de RAM para el proceso Go.
//
// Sin GOMEMLIMIT, el recolector de basura de Go deja crecer el heap hasta que
// el sistema operativo aprieta — en móviles eso termina en OOM o en pausas
// largas de GC justo cuando el usuario está descargando/streaming. 1 GiB
// cubre el trabajo normal de este backend (las descargas van a disco, no a
// memoria) sin causar thrash de GC en dispositivos de gama baja.
const limiteMemoriaMBDefault = 1024

// memoriaMBLimit guarda el límite configurado por FijarLimiteMemoriaMB.
// 0 (o negativo) significa "usar el default".
//
// Lo escribe Flutter (SetMemoryLimitMB) en caliente y lo lee
// AjustarRuntimeMemoria; sin candado esas dos goroutines serían un data race
// sobre el mismo int.
var (
	memoriaMu      sync.RWMutex
	memoriaMBLimit int
)

// getLimiteMemoriaMB lee el límite configurado (0 o negativo = default).
func getLimiteMemoriaMB() int {
	memoriaMu.RLock()
	defer memoriaMu.RUnlock()
	return memoriaMBLimit
}

// AjustarRuntimeMemoria aplica la política de recursos del runtime:
//
//   - Límite blando de heap (GOMEMLIMIT): el GC empieza a recolectar antes de
//     agotar la RAM del dispositivo, evitando OOM y reduciendo las pausas.
//   - GOMAXPROCS acotado a 4: no satura la CPU compartida con el UI de
//     Flutter; las descargas y búsquedas son I/O-bound y 4 workers bastan.
//
// Respeta GOMEMLIMIT/GOMAXPROCS si ya vienen del entorno (Android puede
// inyectarlos desde build.gradle) para no pisar una configuración explícita.
func AjustarRuntimeMemoria() {
	if os.Getenv("GOMEMLIMIT") == "" {
		limite := getLimiteMemoriaMB()
		if limite <= 0 {
			limite = limiteMemoriaMBDefault
		}
		debug.SetMemoryLimit(int64(limite) << 20) // MiB -> bytes
	}
	if os.Getenv("GOMAXPROCS") == "" {
		if n := runtime.NumCPU(); n > 4 {
			runtime.GOMAXPROCS(4)
		}
	}
}

// FijarLimiteMemoriaMB ajusta el tope blando de RAM (en MiB) que usará la
// próxima llamada a AjustarRuntimeMemoria. 0 o negativo restaura el default.
// La usa el puente gobackend (SetMemoryLimitMB) para que Flutter adapte el
// límite a la RAM real del dispositivo.
func FijarLimiteMemoriaMB(n int) {
	memoriaMu.Lock()
	memoriaMBLimit = n
	memoriaMu.Unlock()
	log.Printf("[core] límite de memoria fijado a %d MiB", n)
}
