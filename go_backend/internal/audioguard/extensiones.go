// extensiones.go — el pre-filtro por extensión.
//
// Se aplica ANTES de descargar. Es más débil que Revisar() (una extensión no
// prueba nada: cualquiera puede renombrar un .exe a .flac), pero evita gastar
// ancho de banda y tiempo en un archivo que el par ya declara como no-audio.
// La decisión final SIEMPRE la toma Revisar() mirando los bytes.
package audioguard

import "strings"

// extensionesDeAudio son los contenedores/formato de audio que aceptamos.
// Lista blanca: lo que no esté acá no se descarga.
var extensionesDeAudio = map[string]bool{
	"flac": true, "mp3": true, "ogg": true, "oga": true, "opus": true,
	"m4a": true, "mp4": true, "aac": true, "wav": true, "wave": true,
	"ape": true, "wv": true, "aiff": true, "aif": true, "dsf": true,
	"dff": true, "mpc": true, "amr": true, "wma": true, "alac": true,
}

// ExtensionDeAudio reporta si la extensión declarada es de audio. Acepta con o
// sin punto y sin distinguir mayúsculas.
func ExtensionDeAudio(ext string) bool {
	e := strings.ToLower(strings.TrimSpace(ext))
	e = strings.TrimPrefix(e, ".")
	return extensionesDeAudio[e]
}

// NombreDeArchivoDelPar es una versión defensiva para el nombre que manda el
// par: se queda solo con el nombre base, sin rutas, para que una ruta con
// "../" no pueda escribir fuera de la carpeta de descargas.
func NombreDeArchivoDelPar(ruta string) string {
	normalizada := strings.ReplaceAll(ruta, "\\", "/")
	i := strings.LastIndex(normalizada, "/")
	base := normalizada[i+1:]
	base = strings.TrimSpace(strings.Trim(base, "."))
	if base == "" {
		return "pista"
	}
	return base
}
