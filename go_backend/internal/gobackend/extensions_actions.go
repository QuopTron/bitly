package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/extensions"
	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/flacrescue"
)

func ReinitializeExtension(payload string) string {
	var params struct {
		ExtensionID string `json:"extension_id"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil || params.ExtensionID == "" {
		return jsonErrorString("payload inválido")
	}
	er := getExtRegistry()
	if er == nil {
		return jsonErrorString("no inicializado")
	}
	settings := getAjustesExtension(params.ExtensionID)
	if settings == nil {
		settings = map[string]string{}
	}
	// flac-rescue es un provider NATIVO de Go, no una extensión JS: no tiene
	// sandbox. Re-aplicamos sus ajustes directo al cliente nativo para que el
	// botón "Guardar" de Ajustes → Credenciales surta efecto en caliente.
	if params.ExtensionID == "flac-rescue" {
		if reg != nil {
			if p := reg.Get("flac-rescue"); p != nil {
				if fc, ok := p.(*flacrescue.Client); ok {
					fc.SetSettings(settings)
				}
			}
		}
		return `{"ok":true}`
	}
	sb := er.Runtime().Sandbox(params.ExtensionID)
	if sb == nil {
		return jsonErrorString("extensión no cargada: " + params.ExtensionID)
	}
	if _, err := er.Runtime().CallMethod(params.ExtensionID, "initialize", settings); err != nil {
		return jsonError(err)
	}
	return `{"ok":true}`
}

// InvokeExtensionAction runs a side-effect action exported by an extension
// (SpotiFLAC button-setting contract). The provider extension must export a
// JS method with the action's name; the result is passed back verbatim so the
// UI can surface status/errors from the action itself.
// Flutter contract: {provider, action, args?: [...]}.
func InvokeExtensionAction(payload string) string {
	var params struct {
		Provider string        `json:"provider"`
		Action   string        `json:"action"`
		Args     []interface{} `json:"args"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonErrorString("payload inválido")
	}
	if params.Provider == "" || params.Action == "" {
		return jsonErrorString("faltan provider/action")
	}
	// Los providers NATIVOS (Go) no son extensiones JS: sus acciones se
	// atienden aparte, con el mismo contrato, para que Ajustes → Credenciales
	// pueda tener botones en ambos casos.
	if respuesta, manejada := invocarAccionFlacRescue(params.Provider, params.Action); manejada {
		return respuesta
	}
	if reg == nil {
		return jsonErrorString("no inicializado")
	}
	p := reg.Get(params.Provider)
	ep, ok := p.(*provider.ExtensionProvider)
	if !ok || !ep.HasAction(params.Action) {
		return jsonErrorString("extensión " + params.Provider + " no exporta la acción " + params.Action)
	}
	res, err := ep.InvokeAction(params.Action, params.Args...)
	if err != nil {
		return jsonError(err)
	}
	out, _ := json.Marshal(map[string]interface{}{"ok": true, "result": res})
	return string(out)
}

// LoadExtensionsFromDir loads all .js extensions from a directory into the runtime
// and registers their providers. Used by the desktop backend.
// Flutter contract: {dir_path}.
func LoadExtensionsFromDir(payload string) string {
	var params struct {
		DirPath string `json:"dir_path"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil || params.DirPath == "" {
		return jsonErrorString("falta dir_path")
	}

	// Reuse the existing registry (embedded extensions already loaded by
	// InitGlobalState with signed-session config attached). Only create one
	// Solo crear uno si aun no hay nada cargado (p. ej. desktop sin respaldo embebido).
	er := getExtRegistry()
	if er == nil || er.Runtime().Count() == 0 {
		nuevo, err := extensions.NewRegistry(params.DirPath)
		if err != nil {
			return jsonError(err)
		}
		setExtRegistry(nuevo)
		er = nuevo
	}
	loaded := extensions.LoadDirExtensionsInto(er, params.DirPath, params.DirPath)
	// Re-apply stored settings now that freshly loaded sandboxes exist.
	replicarAjustesExtensiones()
	out, _ := json.Marshal(map[string]interface{}{"ok": true, "loaded": loaded})
	return string(out)
}
