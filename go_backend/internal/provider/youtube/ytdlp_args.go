package youtube

import (
	"os"
	"os/exec"
	"strings"
)

// clientesInnerTubeAnonimos son los clientes que yt-dlp prueba EN ORDEN para
// resolver audio sin cuenta de Google.
//
// Por qué existe: en IPs marcadas (VPN, datacenter, emulador con NAT raro)
// YouTube contesta al cliente web con 403 / "Sign in to confirm you're not a
// bot". Los clientes de TV y embebidos NO piden PO token ni sesión, así que son
// la vía anónima: resuelven el stream igual, aunque suelan dar un formato
// multiplexado de menor bitrate. Es el mismo criterio que usa la extensión
// ytmusic-spotiflac (ver INNERTUBE_CLIENTS): primero los que no piden token.
//
// `default` (el set de yt-dlp) queda al final para no perder el camino conocido
// si YouTube vuelve a aceptar la web.
const clientesInnerTubeAnonimos = "tv_embedded,web_embedded,android_vr,tv,mweb,web"

// argsBypass devuelve los argumentos extra que se agregan a CADA llamada de
// yt-dlp. Se puede ajustar sin recompilar:
//
//	BITLY_YTDLP_ARGS="--extractor-args youtube:player_client=android_vr"
//	  → reemplaza la lista por la que indique el usuario.
//	BITLY_YTDLP_SIN_PLAYER_CLIENT=1
//	  → desactiva el bypass (comportamiento histórico de yt-dlp).
func argsBypass() []string {
	if os.Getenv("BITLY_YTDLP_SIN_PLAYER_CLIENT") == "1" {
		return nil
	}
	if extra := strings.TrimSpace(os.Getenv("BITLY_YTDLP_ARGS")); extra != "" {
		return strings.Fields(extra)
	}
	return []string{
		"--extractor-args",
		"youtube:player_client=" + clientesInnerTubeAnonimos,
	}
}

// ejecutarYtDlp corre yt-dlp con los argumentos de bypass y, si la llamada
// falla, reintenta UNA vez SIN ellos.
//
// El reintento no es un lujo: `--extractor-args` con un cliente que la versión
// instalada de yt-dlp ya no conoce la hace fallar ANTES de intentar nada. Sin el
// reintento, actualizar la lista de clientes desde acá podía dejar a TODO el
// mundo sin audio de YouTube; con él, el peor caso es el comportamiento de
// antes (que es exactamente lo que había sin esta mejora).
func ejecutarYtDlp(ruta string, args []string) ([]byte, error) {
	bypass := argsBypass()
	if len(bypass) > 0 {
		completos := make([]string, 0, len(bypass)+len(args))
		completos = append(completos, bypass...)
		completos = append(completos, args...)
		if salida, err := exec.Command(ruta, completos...).Output(); err == nil {
			return salida, nil
		}
	}
	return exec.Command(ruta, args...).Output()
}
