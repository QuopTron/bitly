package gobackend

import (
	"log"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
)

// Precalentamiento de extensiones.
//
// El arranque diferido saca la compilación del JS del momento más caro del
// launch —cuando el sistema operativo todavía está inflando la app y cada
// milisegundo de CPU se ve como frames perdidos—, pero no la elimina: las
// extensiones hay que compilarlas antes o después. Esta pasada las compila en
// segundo plano, después de que el arranque ya devolvió, para que el primer uso
// del usuario encuentre todo listo sin haberle cobrado el costo al splash.
//
// Secuencial a propósito: nueve compilaciones en paralelo acapararían todos los
// núcleos justo cuando el UI los necesita.

var (
	warmupMu sync.Mutex
	// warmupCancelar cancela la pasada anterior. InitGlobalState puede
	// re-ejecutarse (tests y re-init en caliente) y no tiene sentido acumular
	// pasadas de precalentamiento sobre registros viejos.
	warmupCancelar chan struct{}
)

// precalentarExtensiones compila en [espera] las extensiones que quedaron
// diferidas. Best-effort: un fallo se registra y no frena a las demás.
func precalentarExtensiones(exts []bundled_extensions.RegisteredExtension, espera time.Duration) {
	if len(exts) == 0 || getExtRegistry() == nil {
		return
	}

	// Orden: primero la fuente primaria de búsqueda y las que traen feed (lo
	// que el usuario toca al abrir la app), después el resto. Se resuelve ANTES
	// del goroutine para no leer un slice de un global que un re-init puede
	// reescribir.
	orden := ordenDePrecalentamiento(exts)

	warmupMu.Lock()
	if warmupCancelar != nil {
		close(warmupCancelar)
	}
	cancelar := make(chan struct{})
	warmupCancelar = cancelar
	warmupMu.Unlock()

	go func() {
		select {
		case <-time.After(espera):
		case <-cancelar:
			return
		}
		compiladas := 0
		for _, id := range orden {
			select {
			case <-cancelar:
				return
			default:
			}
			er := getExtRegistry()
			if er == nil {
				return
			}
			if !er.Runtime().IsDeferred(id) {
				continue
			}
			if err := er.Runtime().EnsureLoaded(id); err != nil {
				log.Printf("[warmup] %s: no se pudo compilar: %v", id, err)
				continue
			}
			compiladas++
		}
		if compiladas > 0 {
			log.Printf("[warmup] %d extensiones compiladas en segundo plano", compiladas)
		}
	}()
}

// ordenDePrecalentamiento prioriza lo que el usuario toca primero.
func ordenDePrecalentamiento(exts []bundled_extensions.RegisteredExtension) []string {
	orden := make([]string, 0, len(exts))
	for _, ext := range exts {
		if ext.Search.Primary {
			orden = append(orden, ext.ID)
		}
	}
	for _, ext := range exts {
		if ext.HasHomeFeed && !ext.Search.Primary {
			orden = append(orden, ext.ID)
		}
	}
	for _, ext := range exts {
		if ext.Search.Primary || ext.HasHomeFeed {
			continue
		}
		orden = append(orden, ext.ID)
	}
	return orden
}
