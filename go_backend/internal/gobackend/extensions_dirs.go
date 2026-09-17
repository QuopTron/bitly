// ─────────────────────────────────────────────────────────────
// extensions_dirs.go — Publica en el sandbox de extensiones los
// directorios REALES de la app donde pueden escribir archivos.
//
// Por qué existe: las extensiones (ytmusic-spotiflac, deezer, amazon,
// soundcloud) bajan el audio con file.download, y el sandbox solo
// permitía escribir dentro de "." (el directorio de trabajo del
// proceso). En PC ese CWD es la carpeta desde donde se lanzó el exe,
// así que cualquier carpeta de descargas elegida por el usuario
// bloqueaba TODAS las descargas con "not in allowed directories"; en
// Android, donde el CWD es "/", el filtro no hacía nada (comportamiento
// distinto por plataforma para el mismo código).
//
// Acá se juntan las carpetas que sí importan —descargas del usuario,
// caché de streaming, portadas, extensiones y binarios— y se registran
// en el sandbox. Se llama en cada cambio de configuración, no una sola
// vez al arrancar: el usuario puede mover la carpeta en Ajustes y las
// descargas deben seguir funcionando sin reiniciar.
//
// Se conecta con: extensions.SetDirectoriosPermitidos, exports_init.go
// (arranque) y actions_config.go (setDownloadDirectory/setBackendConfig).
// Parte del flujo: descarga de audio/video/letras por extensiones.
// ─────────────────────────────────────────────────────────────

package gobackend

import (
	"log"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// sincronizarDirectoriosExtensiones reúne los directorios escribibles de la
// app y los publica en el sandbox. Best-effort: una ruta que no se puede
// resolver simplemente no se agrega.
func sincronizarDirectoriosExtensiones() {
	dirs := []string{
		getDownloadDir(),
		dirExtensiones(),
		dirDatosBin(),
		rutaDirPortadas(),
	}
	// La caché de streaming vive DENTRO de la carpeta de descargas, pero se
	// agrega aparte porque cuando no hay carpeta configurada cae a os.TempDir().
	dirs = append(dirs, streamCacheDirPath())
	extensions.SetDirectoriosPermitidos(dirs)
	// Una línea por cambio (no por descarga): si una escritura de extensión
	// falla, el log dice exactamente qué carpetas estaban permitidas.
	firma := strings.Join(extensions.DirectoriosPermitidos(), "|")
	if firma != ultimaFirmaDirs {
		ultimaFirmaDirs = firma
		log.Printf("[extensions] carpetas escribibles: %s", firma)
	}
}

// ultimaFirmaDirs recuerda la última lista publicada para no repetir el log.
var ultimaFirmaDirs string
