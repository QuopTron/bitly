package provider

import (
	"fmt"
)

// ─── Extension actions (SpotiFLAC "button" setting contract) ────────────────
//
// Extensions may export side-effect methods that the UI exposes as buttons in
// the provider settings (e.g. "Reiniciar sesión", "Limpiar caché de tokens").
// The action runs under its own "action" cooldown bucket so a slow/failing
// action never cools the provider's search/download/playback paths.

// HasAction reports whether the extension exports a callable [action].
func (p *ExtensionProvider) HasAction(action string) bool {
	if p == nil || p.runtime == nil || action == "" {
		return false
	}
	return p.runtime.HasMethod(p.extID, action)
}

// InvokeAction calls an exported extension method (arbitrary args) scoped to
// the isolated "action" bucket. A missing method or a JS failure surfaces as an
// error so the UI can show why the button did nothing.
func (p *ExtensionProvider) InvokeAction(action string, args ...interface{}) (interface{}, error) {
	if p == nil || p.runtime == nil {
		return nil, fmt.Errorf("ext %s: runtime no disponible", p.extID)
	}
	if action == "" {
		return nil, fmt.Errorf("ext %s: falta action", p.extID)
	}
	res, err := p.callOp("action", action, args...)
	if err != nil {
		return nil, fmt.Errorf("ext %s: action %s falló: %w", p.extID, action, err)
	}
	return res, nil
}
