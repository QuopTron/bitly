// ─────────────────────────────────────────────────────────────
// extensions_actions_qobuz.go — Acciones de la extensión qobuz-web, expuestas
// por el mismo contrato {provider, action, args} que usan las extensiones.
//
// Por qué existe: cuando el pool de Qobuz queda vacío la descarga directa se
// apaga en silencio. Con `estadoPool`, Ajustes puede pedir el motivo (endpoint
// caído vs. sin tokens vivos) y mostrarlo, en vez de dejar al usuario sin saber
// por qué no baja.
//
// Acciones: estadoPool → informe del pool (ver sessionpool/qobuz_diagnostico.go).
//
// Se conecta con: extensions_actions.go (InvokeExtensionAction lo llama antes
// del camino normal de las extensiones JS) y sessionpool.DiagnosticoPoolQobuz.
// Parte del flujo: Ajustes → Descargas → pool de Qobuz.
// ─────────────────────────────────────────────────────────────

package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/sessionpool"
)

// invocarAccionQobuzWeb atiende las acciones de qobuz-web. Devuelve [manejada]
// en false cuando el provider no es suyo, para que el llamador siga por el
// camino normal de las extensiones JS.
func invocarAccionQobuzWeb(providerName, action string) (respuesta string, manejada bool) {
	if providerName != "qobuz-web" {
		return "", false
	}
	switch action {
	case "estadoPool":
		// Los ajustes guardados son los que la expansión real usaría, así que
		// el informe describe el pool TAL COMO quedó, no una configuración
		// distinta.
		settings := getAjustesExtension("qobuz-web")
		diag := sessionpool.DiagnosticoPoolQobuz(
			nil, credencialesPropiasQobuz(settings), fuentesPoolQobuz(settings), "", "")
		out, err := json.Marshal(map[string]interface{}{
			"ok":     true,
			"result": diag,
		})
		if err != nil {
			return jsonError(err), true
		}
		return string(out), true
	default:
		return jsonErrorString("qobuz-web no exporta la acción " + action), true
	}
}
