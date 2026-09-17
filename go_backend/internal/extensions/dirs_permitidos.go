// ─────────────────────────────────────────────────────────────
// dirs_permitidos.go — Directorios donde las extensiones JS pueden
// ESCRIBIR archivos (file.download).
//
// Por qué existe: el sandbox nace con la lista fija {"."} (el directorio
// de trabajo del proceso). En la app la carpeta de descargas es la que
// eligió el usuario (Música, SD, carpeta propia), que NO está dentro del
// CWD — así que cada descarga de una extensión (ytmusic-spotiflac,
// deezer, amazon, soundcloud) moría con "path ... is not in allowed
// directories" y el usuario veía la descarga fallar sin motivo. En
// Android el CWD es "/" y el filtro no hacía nada; en PC bloqueaba TODO.
//
// Acá vive la lista REAL, que el puente de la app actualiza cuando
// cambia la carpeta de descargas (setDownloadDirectory /
// setBackendConfig). El "." del manifest se conserva para no romper los
// casos donde el CWD sí es válido.
//
// Se conecta con: file_download.go (resolverRuta la consulta) y
// gobackend (sincronizarDirectoriosExtensiones la llena).
// Parte del flujo: descarga de audio/video/letras por extensiones.
// ─────────────────────────────────────────────────────────────

package extensions

import (
	"path/filepath"
	"runtime"
	"strings"
	"sync"
)

var (
	dirsPermitidosMu sync.RWMutex
	// dirsPermitidos son las raíces absolutas con permiso de escritura. La
	// primera es siempre la carpeta de descargas del usuario.
	dirsPermitidos []string
)

// SetDirectoriosPermitidos reemplaza la lista de raíces escribibles. Las
// entradas vacías se descartan y las rutas se normalizan a absolutas: una
// ruta relativa dependería del CWD del proceso y volvería a bloquear la
// descarga según cómo se lanzó la app.
func SetDirectoriosPermitidos(dirs []string) {
	limpios := make([]string, 0, len(dirs))
	vistos := map[string]bool{}
	for _, d := range dirs {
		d = strings.TrimSpace(d)
		if d == "" {
			continue
		}
		abs, err := filepath.Abs(d)
		if err != nil {
			continue
		}
		abs = filepath.Clean(abs)
		clave := abs
		if runtime.GOOS == "windows" {
			clave = strings.ToLower(clave)
		}
		if vistos[clave] {
			continue
		}
		vistos[clave] = true
		limpios = append(limpios, abs)
	}
	dirsPermitidosMu.Lock()
	dirsPermitidos = limpios
	dirsPermitidosMu.Unlock()
}

// DirectoriosPermitidos devuelve una copia de las raíces registradas.
func DirectoriosPermitidos() []string {
	dirsPermitidosMu.RLock()
	defer dirsPermitidosMu.RUnlock()
	return append([]string(nil), dirsPermitidos...)
}

// rutaPermitida reporta si [abs] (ya absoluta) cae dentro de alguna de las
// raíces permitidas.
func rutaPermitida(abs string) bool {
	for _, dir := range DirectoriosPermitidos() {
		if dentroDeRuta(abs, dir) {
			return true
		}
	}
	return false
}

// dentroDeRuta compara por límite de separador: `/a/bc` NO está dentro de
// `/a/b` (un HasPrefix crudo dejaría una carpeta hermana hacerse pasar por
// la permitida). En Windows la comparación ignora mayúsculas, porque el
// usuario puede elegir la misma carpeta escrita distinto.
func dentroDeRuta(abs, dir string) bool {
	a := filepath.Clean(abs)
	d := filepath.Clean(dir)
	if runtime.GOOS == "windows" {
		a = strings.ToLower(a)
		d = strings.ToLower(d)
	}
	if a == d {
		return true
	}
	if !strings.HasSuffix(d, string(filepath.Separator)) {
		d += string(filepath.Separator)
	}
	return strings.HasPrefix(a, d)
}
