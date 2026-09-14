package gobackend

import (
	"encoding/json"
	"log"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider/flacrescue"
	"github.com/zarz/bitly/go_backend/internal/provider/soulseek"
	"github.com/zarz/bitly/go_backend/internal/sessionpool"
)

// SetExtensionSettings stores settings for an extension in memory and pushes them
// to the JS initialize() function so credentials take effect.
// Flutter contract: {extension_id, settings} where settings is a JSON string.
func SetExtensionSettings(payload string) string {
	var params struct {
		ExtensionID string `json:"extension_id"`
		Settings    string `json:"settings"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonErrorString("payload inválido")
	}
	if params.ExtensionID == "" {
		return jsonErrorString("falta extension_id")
	}
	settings := map[string]string{}
	if params.Settings != "" {
		if err := json.Unmarshal([]byte(params.Settings), &settings); err != nil {
			return jsonError(err)
		}
	}
	setAjustesExtension(params.ExtensionID, settings)

	// Caso especial: flac-rescue es un provider nativo de Go, no una
	// extensión JS. Le empujamos los ajustes (espejos, origin, formato)
	// directo al cliente cuando llegan desde Ajustes → Credenciales.
	if params.ExtensionID == "flac-rescue" && reg != nil {
		if p := reg.Get("flac-rescue"); p != nil {
			if fc, ok := p.(*flacrescue.Client); ok {
				fc.SetSettings(settings)
			}
		}
	}

	// Caso especial: soulseek es un provider nativo (no una extensión JS).
	// Recibe el usuario y la contraseña que Flutter guarda tras el botón
	// "Siguiente"; sin credenciales el cliente queda inerte y NO abre red.
	if params.ExtensionID == "soulseek" && reg != nil {
		if p := reg.Get("soulseek"); p != nil {
			if sc, ok := p.(*soulseek.Client); ok {
				sc.SetSettings(settings)
			}
		}
	}

	// Pool de sesiones: si la extensión trae fuentes configuradas, se
	// arman en SEGUNDO PLANO (descargar + validar no puede bloquear el
	// guardado de ajustes) y cuando están listas se re-empujan.
	if tieneFuentesDePool(settings) {
		go expandirPoolDeSesiones(params.ExtensionID, copiarAjustes(settings))
	}

	// Push settings to the JS initialize() function if the extension is loaded.
	if er := getExtRegistry(); er != nil {
		if sb := er.Runtime().Sandbox(params.ExtensionID); sb != nil && sb.VM != nil {
			if _, err := er.Runtime().CallMethod(params.ExtensionID, "initialize", settings); err == nil {
				return `{"ok":true}`
			}
		}
		// The extension sandbox puede sin exist yet (startup race: el push puede
		// land while extensions are still loading). Settings are stored above;
		// retry initialize for a short window so credentials are not lost — a
		// subsequent replay at load time covers the case where even this retry
		// window closes before the sandbox appears.
		go retryInitializeAfterLoad(params.ExtensionID, settings)
	}
	return `{"ok":true}`
}

// retryInitializeAfterLoad repeatedly calls initialize() on an extension once
// its sandbox becomes available. Bounded (~6s) and best-effort: if the window
// passes the settings stay stored and replicarAjustesExtensiones() applies
// them when the sandbox finally loads.
func retryInitializeAfterLoad(extID string, settings map[string]string) {
	for i := 0; i < 20; i++ {
		time.Sleep(300 * time.Millisecond)
		er := getExtRegistry()
		if er == nil {
			return
		}
		sb := er.Runtime().Sandbox(extID)
		if sb == nil || sb.VM == nil {
			continue
		}
		_, err := er.Runtime().CallMethod(extID, "initialize", settings)
		if err == nil {
			return
		}
	}
}

// clavesFuentesDePool son los campos donde el usuario pega las URLs de
// donde sacar credenciales, por extensión. Sin fuentes no hay pool que
// armar y no se toca la red.
var clavesFuentesDePool = []string{"arlPoolUrls", "tidalPoolUrls", "qobuzPoolUrls"}

// tieneFuentesDePool indica si el usuario configuró alguna fuente.
func tieneFuentesDePool(settings map[string]string) bool {
	for _, clave := range clavesFuentesDePool {
		if strings.TrimSpace(settings[clave]) != "" {
			return true
		}
	}
	return false
}

// copiarAjustes clona el mapa para que la goroutine del pool no comparta
// memoria con extSettings (que el arranque lee desde otro hilo).
func copiarAjustes(settings map[string]string) map[string]string {
	copia := make(map[string]string, len(settings))
	for k, v := range settings {
		copia[k] = v
	}
	return copia
}

// expandirPoolDeSesiones descarga las fuentes configuradas, se queda solo
// con las credenciales VIVAS (validándolas contra el servicio real) y
// re-empuja el resultado a la extensión.
//
// Así el usuario no vuelve a pegar una credencial a mano cuando una
// muere: el pool rota solo entre las que siguen sirviendo.
func expandirPoolDeSesiones(extID string, settings map[string]string) {
	switch extID {
	case "deezer":
		propias := sessionpool.SepararCredenciales(settings["arl"])
		fuentes := sessionpool.SepararCredenciales(settings["arlPoolUrls"])
		res := sessionpool.ConstruirPoolARP(nil, propias, fuentes, "")
		if !hayCredenciales(extID, res) {
			return
		}
		settings["arl"] = res.Usables[0]
		settings["arlPool"] = strings.Join(res.Usables, "\n")
	case "tidal-web":
		propias := sessionpool.SepararCredenciales(settings["tidalAccessToken"])
		fuentes := sessionpool.SepararCredenciales(settings["tidalPoolUrls"])
		res := sessionpool.ConstruirPoolTidal(nil, propias, fuentes, "")
		if !hayCredenciales(extID, res) {
			return
		}
		settings["tidalAccessToken"] = res.Usables[0]
		settings["tidalTokenPool"] = strings.Join(res.Usables, "\n")
	case "qobuz-web":
		// La credencial propia es la cuenta (email:password); si además
		// hay una sola cuenta en los campos sueltos, se arma el par.
		propias := sessionpool.SepararCredenciales(settings["qobuzPool"])
		if correo, clave := strings.TrimSpace(settings["email"]), settings["password"]; correo != "" && clave != "" {
			propias = append([]string{correo + ":" + clave}, propias...)
		}
		fuentes := sessionpool.SepararCredenciales(settings["qobuzPoolUrls"])
		res := sessionpool.ConstruirPoolQobuz(nil, propias, fuentes, "", "")
		if !hayCredenciales(extID, res) {
			return
		}
		settings["qobuzPool"] = strings.Join(res.Usables, "\n")
	default:
		return
	}

	// Esta goroutine (pool de sesiones) guarda en paralelo a las lecturas de
	// acciones/arranque: entra por el candado.
	setAjustesExtension(extID, settings)
	er := getExtRegistry()
	if er == nil {
		return
	}
	if _, err := er.Runtime().CallMethod(extID, "initialize", settings); err != nil {
		log.Printf("[sessionpool] %s: no se pudo empujar el pool: %v", extID, err)
	}
}

// hayCredenciales reporta si el pool quedó con algo usable. Si no, el
// llamador corta y se conservan los ajustes que el usuario ya tenía
// (nunca empeorar lo que andaba).
func hayCredenciales(extID string, res sessionpool.Resultado) bool {
	log.Printf("[sessionpool] %s: %d usables, %d descartadas, %d fuentes caídas",
		extID, len(res.Usables), res.Descartadas, len(res.FuentesCaidas))
	return len(res.Usables) > 0
}

// replicarAjustesExtensiones vuelve a aplicar cada ajuste guardado a una
// extensión cuyo sandbox ya está presente. Se llama después de cada paso de
// carga de extensiones (InitGlobalState, initExtensionSystem,
// loadExtensionsFromDir) para que un push de credenciales que corrió contra
// una carga lenta de sandbox no se pierda.
func replicarAjustesExtensiones() int {
	if getExtRegistry() == nil {
		return 0
	}
	// Copia bajo el candado y recorre la copia: el push a la VM de JS es lento
	// y no debe retener el candado mientras otra goroutine guarda ajustes.
	snapshot := snapshotAjustesExtensiones()
	if snapshot == nil {
		return 0
	}
	applied := 0
	for extID, settings := range snapshot {
		er := getExtRegistry()
		if er == nil {
			break
		}
		sb := er.Runtime().Sandbox(extID)
		if sb == nil || sb.VM == nil {
			continue
		}
		if _, err := er.Runtime().CallMethod(extID, "initialize", settings); err == nil {
			applied++
		}
	}
	return applied
}

// ReinitializeExtension re-runs the JS initialize() with the stored settings.
