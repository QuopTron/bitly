package download

import (
	"strings"
	"sync"
	"time"
)

// Memoria de proveedores que DECLARARON no poder entregar audio en esta sesión
// (catálogo sin cuenta propia, extensión metadata-only).
//
// Por qué existe: cuando un catálogo no tiene cuenta configurada responde al
// instante "sin cuenta propia: el audio se resuelve desde una fuente abierta".
// Eso no es un fallo transitorio: ese proveedor no puede servir audio hasta que
// el usuario configure su cuenta. Sin memoria, CADA descarga volvía a intentarlo
// y la carrera gastaba ~20 de sus 50s de presupuesto en fuentes que no podían
// ganar, antes de llegar a las que sí pueden (InnerTube/YouTube, SoundCloud,
// Internet Archive). Con la memoria, la primera descarga descubre y las
// siguientes van directo a lo que funciona.
//
// El registro es en memoria (se limpia al reiniciar el backend) y con vencimiento
// corto: si el usuario agrega sus credenciales, el proveedor vuelve a intentarse
// solo. También se limpia cuando cambia la prioridad de proveedores.
var (
	sinAudioMu     sync.Mutex
	sinAudioHasta  = map[string]time.Time{}
	sinAudioTTL    = 10 * time.Minute
	sinAudioMarcas = []string{
		"sin cuenta propia",
		"sin sesión propia",
		"sin sesion propia",
		"metadata-only",
		"no puede entregar audio",
	}
)

// esErrorSinAudio reconoce los motivos que significan "este proveedor no sirve
// audio ahora mismo" (y que no se arreglan reintentando).
func esErrorSinAudio(errMsg string) bool {
	m := strings.ToLower(errMsg)
	for _, marca := range sinAudioMarcas {
		if strings.Contains(m, marca) {
			return true
		}
	}
	return false
}

// marcarProviderSinAudio registra que [name] no puede entregar audio por ahora.
func marcarProviderSinAudio(name, errMsg string) {
	if name == "" || !esErrorSinAudio(errMsg) {
		return
	}
	sinAudioMu.Lock()
	sinAudioHasta[name] = time.Now().Add(sinAudioTTL)
	sinAudioMu.Unlock()
}

// providerSinAudio informa si [name] está marcado como incapaz de servir audio.
func providerSinAudio(name string) bool {
	sinAudioMu.Lock()
	defer sinAudioMu.Unlock()
	hasta, ok := sinAudioHasta[name]
	if !ok {
		return false
	}
	if time.Now().After(hasta) {
		delete(sinAudioHasta, name)
		return false
	}
	return true
}

// limpiarProvidersSinAudio olvida las marcas: se usa cuando el usuario cambia
// algo que puede habilitar esos catálogos (prioridad de proveedores, sesiones).
func limpiarProvidersSinAudio() {
	sinAudioMu.Lock()
	sinAudioHasta = map[string]time.Time{}
	sinAudioMu.Unlock()
}
