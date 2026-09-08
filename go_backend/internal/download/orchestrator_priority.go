package download

import (
	"log"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// lastResortProviders son fuentes lossy de búsqueda por nombre cuyos resultados
// de "mismo título" a veces son un remix/cover/subida equivocada. En la carrera
// paralela nunca ganan sobre una fuente exacta que aún descarga; solo ganan
// cuando ninguna fuente exacta puede terminar.
var lastResortProviders = []string{"soundcloud", "youtube"}

// esProviderUltimoRecurso indica si el proveedor es de último recurso.
func esProviderUltimoRecurso(name string) bool {
	for _, p := range lastResortProviders {
		if p == name {
			return true
		}
	}
	return false
}

// SetDownloadProviderPriority configura el orden de respaldo usado por Download.
// providerIDs van de mejor a peor, espejando el SetProviderPriority de
// SpotiFLAC: se deduplican y se descartan nombres inválidos o que no pueden
// streamear.
//
// Semántica:
//   - slice nil/vacío → restaura el orden por defecto integrado (que agrega
//     cualquier proveedor registrado restante después de la lista preferida).
//   - slice no vacío → el orden de respaldo es EXACTAMENTE la lista dada
//     (sanitizada), así los proveedores deshabilitados quedan realmente fuera
//     y nunca se intentan (p. ej. una fuente con rate-limit o bloqueada).
func (o *Orchestrator) SetDownloadProviderPriority(providerIDs []string) {
	o.mu.Lock()
	defer o.mu.Unlock()
	if len(providerIDs) == 0 {
		o.priorityOrder = preferredStreamOrder
		o.fallbackOrder = construirOrdenFallback(o.providers, preferredStreamOrder)
		log.Printf("[orchestrator] download provider priority reset to default: %v", o.fallbackOrder)
		return
	}
	prio := sanitizarPrioridadProvidersDescarga(providerIDs, o.providers)
	o.priorityOrder = prio
	o.fallbackOrder = prio
	log.Printf("[orchestrator] download provider priority set (exact): %v", o.fallbackOrder)
}

// sanitizarPrioridadProvidersDescarga descarta duplicados, proveedores no
// registrados y no capaces de streamear, preservando el orden. Las entradas
// inválidas se ignoran sin borrar nombres posteriores, como el sanitizador de
// SpotiFLAC.
func sanitizarPrioridadProvidersDescarga(providerIDs []string, reg *provider.Registry) []string {
	seen := map[string]bool{}
	neverStream := map[string]bool{
		"musicbrainz": true,
		"spotify":     true,
		"apple":       true,
	}
	out := make([]string, 0, len(providerIDs))
	for _, name := range providerIDs {
		name = strings.TrimSpace(name)
		if name == "" || seen[name] || neverStream[name] {
			continue
		}
		p := reg.Get(name)
		if p == nil {
			continue
		}
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			continue
		}
		seen[name] = true
		out = append(out, name)
	}
	return out
}
