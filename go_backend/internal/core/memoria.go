package core

import (
	"log"
	"os"
	"runtime"
	"runtime/debug"
	"sync"
)

// limiteMemoriaMBDefault es el tope blando de RAM para el proceso Go cuando NO
// se puede leer la RAM del dispositivo (escritorio raro, /proc ausente).
//
// Antes eran 1024 MiB FIJOS para todo el mundo, y además nadie los ajustaba:
// SetMemoryLimitMB existe para que la app lo adapte, pero no había una sola
// llamada en todo el proyecto. En un teléfono de 2 GB eso equivale a no tener
// protección — Android mata la app mucho antes de 1 GiB (los límites por app
// rondan 256–512 MB y Android 17 añade límites propios que terminan procesos
// antes de la presión global) — y el recolector, al no ver presión, deja crecer
// el heap y después hace pausas largas en tandas grandes, justo mientras se
// reproduce o descarga. Ver esLimiteMemoriaMB y memoriaAdaptada.
const limiteMemoriaMBDefault = 384

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
//     agotar la RAM del dispositivo, evitando OOM y reduciendo las pausas. El
//     valor sale de la RAM REAL del aparato (memoriaAdaptada) para que sirva
//     igual en un gama baja de 2 GB que en un tope de gama.
//   - GOMAXPROCS acotado a 4: no satura la CPU compartida con el UI de
//     Flutter; las descargas y búsquedas son I/O-bound y 4 workers bastan.
//
// Respeta GOMEMLIMIT/GOMAXPROCS si ya vienen del entorno (Android puede
// inyectarlos desde build.gradle) para no pisar una configuración explícita.
// El valor que ponga la app (FijarLimiteMemoriaMB) gana sobre el adaptativo.
func AjustarRuntimeMemoria() {
	if os.Getenv("GOMEMLIMIT") == "" {
		limite := getLimiteMemoriaMB()
		if limite <= 0 {
			limite = memoriaAdaptada()
		}
		debug.SetMemoryLimit(int64(limite) << 20) // MiB -> bytes
		log.Printf("[core] GOMEMLIMIT: %d MiB", limite)
	}
	if os.Getenv("GOMAXPROCS") == "" {
		if n := runtime.NumCPU(); n > 4 {
			runtime.GOMAXPROCS(4)
		}
	}
}

// memoriaAdaptada elige el tope de heap de Go según la RAM del dispositivo.
//
// Criterio (guía del GC de Go + límites por app de Android): el tope va MUY por
// debajo de la RAM total porque este proceso convive con Flutter, con el
// decodificador de audio y con el sistema — no es el único inquilino, y el
// recolector no ve esa presión. Al mismo tiempo queda holgado sobre el conjunto
// de trabajo real (unos 40–80 MB: los sandboxes de las 9 extensiones, las
// cachés de metadata y los trozos de audio en vuelo), porque un tope por debajo
// del conjunto vivo hace que el GC corra sin parar ("thrash") y eso sí se
// siente como tirones.
func memoriaAdaptada() int {
	totalMB, disponibleMB, ok := memoriaDelSistemaMB()
	if !ok || totalMB <= 0 {
		return limiteMemoriaMBDefault
	}
	limite := esLimiteMemoriaMB(totalMB)
	// Si el aparato arranca ya apretado (poca RAM libre), bajar más: es
	// preferible un GC más activo que una muerte por OOM en segundo plano.
	if disponibleMB > 0 && disponibleMB < limite*3/2 {
		reducido := disponibleMB / 2
		if reducido < limiteMinimoMemoriaMB {
			reducido = limiteMinimoMemoriaMB
		}
		if reducido < limite {
			limite = reducido
		}
	}
	return limite
}

// limiteMinimoMemoriaMB es el piso: por debajo, el GC trabajaría en bucle sin
// dejar avanzar el trabajo real.
const limiteMinimoMemoriaMB = 128

// esLimiteMemoriaMB escala el tope por gama de RAM total.
func esLimiteMemoriaMB(totalMB int) int {
	switch {
	case totalMB <= 2048:
		return 192
	case totalMB <= 3072:
		return 256
	case totalMB <= 4096:
		return 320
	case totalMB <= 6144:
		return 448
	case totalMB <= 8192:
		return 512
	default:
		return 768
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
