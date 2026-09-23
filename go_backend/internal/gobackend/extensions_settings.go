package gobackend

import (
	"encoding/json"
	"log"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider/flacrescue"
	"github.com/zarz/bitly/go_backend/internal/provider/soulseek"
	"github.com/zarz/bitly/go_backend/internal/provider/youtube"
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

	// Caso especial: youtube es un provider nativo. Recibe la instancia
	// propia de cobalt (respaldo de descarga cuando yt-dlp falla); sin URL
	// queda apagado y no abre ninguna conexión.
	if params.ExtensionID == "youtube" && reg != nil {
		if p := reg.Get("youtube"); p != nil {
			if yc, ok := p.(*youtube.Client); ok {
				yc.SetSettings(settings)
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

	// Push settings to the JS initialize() function.
	if er := getExtRegistry(); er != nil {
		sb := er.Runtime().Sandbox(params.ExtensionID)
		// QueueSettings devuelve false cuando la extensión todavía no se compiló:
		// los ajustes quedan encolados y se aplican en cuanto se compile (ver
		// Runtime.EnsureLoaded). No se compila acá a propósito — guardar
		// credenciales no debería costar traer la extensión entera, y este push
		// corre al arrancar, cuando la app empuja todo lo guardado.
		if sb != nil {
			if !sb.QueueSettings(copiarAjustes(settings)) {
				return `{"ok":true}`
			}
			if _, err := er.Runtime().CallMethod(params.ExtensionID, "initialize", settings); err == nil {
				return `{"ok":true}`
			}
		}
	}
	return `{"ok":true}`
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
	// La extensión del pool acaba de configurarse, así que se compila si hacía
	// falta; si no se pudo, el pool queda encolado y se aplica al compilar.
	if sb := er.Runtime().Sandbox(extID); sb != nil && !sb.QueueSettings(copiarAjustes(settings)) {
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
		if sb == nil {
			continue
		}
		// Sin compilar: los ajustes quedan encolados y se aplican al compilar.
		// Compilarlas todas acá era justamente lo que devolvía al arranque el
		// costo de las nueve extensiones.
		if !sb.QueueSettings(copiarAjustes(settings)) {
			continue
		}
		if _, err := er.Runtime().CallMethod(extID, "initialize", settings); err == nil {
			applied++
		}
	}
	return applied
}

// ReinitializeExtension re-runs the JS initialize() with the stored settings.
