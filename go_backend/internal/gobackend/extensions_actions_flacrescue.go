// ─────────────────────────────────────────────────────────────
// extensions_actions_flacrescue.go — Acciones del provider NATIVO
// flac-rescue (Go, sin sandbox JS) expuestas por el mismo contrato que
// usan las extensiones: {provider, action, args}.
//
// Por qué existe: InvokeExtensionAction solo atiende providers de
// extensión (*provider.ExtensionProvider). flac-rescue es nativo, así
// que sus botones de Ajustes → Credenciales no tenían por dónde
// responder. Acá se le da ese camino, igual que ya se hizo con sus
// ajustes (SetExtensionSettings) y su reinicialización.
//
// Acciones: probarCanal → informe del canal Qobuz (ver qobuz_diagnostico.go).
//
// Se conecta con: extensions_actions.go (InvokeExtensionAction lo llama
// primero) y provider/flacrescue (DiagnosticoQobuz).
// Parte del flujo: Ajustes → Credenciales → Rescate de audio.
// ─────────────────────────────────────────────────────────────

package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/provider/flacrescue"
)

// invocarAccionFlacRescue atiende las acciones de flac-rescue. Devuelve
// [manejada] en false cuando el provider no es suyo, para que el llamador
// siga por el camino normal de las extensiones JS.
func invocarAccionFlacRescue(providerName, action string) (respuesta string, manejada bool) {
	if providerName != "flac-rescue" {
		return "", false
	}
	switch action {
	case "probarCanal":
		cliente := clienteFlacRescue()
		if cliente == nil {
			return jsonErrorString("flac-rescue no está cargado"), true
		}
		out, err := json.Marshal(map[string]interface{}{
			"ok":     true,
			"result": cliente.DiagnosticoQobuz(),
		})
		if err != nil {
			return jsonError(err), true
		}
		return string(out), true
	default:
		return jsonErrorString("flac-rescue no exporta la acción " + action), true
	}
}

// clienteFlacRescue devuelve el provider nativo ya registrado (nil si el
// registro todavía no se inicializó).
func clienteFlacRescue() *flacrescue.Client {
	if reg == nil {
		return nil
	}
	p := reg.Get("flac-rescue")
	if p == nil {
		return nil
	}
	fc, _ := p.(*flacrescue.Client)
	return fc
}
