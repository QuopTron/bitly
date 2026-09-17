// ─────────────────────────────────────────────────────────────
// limpieza_restos.go — Limpieza de restos que las descargas dejan en
// la carpeta del usuario.
//
// Por qué existe: el orquestador lanza los candidatos en PARALELO y se
// queda con el primero que termina; los demás siguen corriendo como
// "compañeros". Si la app se cierra (o el sistema mata el proceso)
// mientras uno de esos compañeros baja por tramos, su archivo temporal
// queda en Descargas para siempre: los vimos de varios cientos de MB
// con el nombre `dl-par-<id>-<huella>-<aleatorio>.<ext>`. Nadie los
// reanuda (son offsets absolutos) y nadie los borra, así que se
// acumulaban en la carpeta del usuario.
//
// Qué borra: SOLO restos que ya no sirven para nada —
//   · `dl-par-*`   temporales de descarga por tramos (nunca reanudables),
//   · `*.tags.partial.*` copias del etiquetado interrumpido,
//   · `*.partial`  restos del staging.
// Los parciales reanudables (`dl-*` secuenciales) se CONSERVAN: borrarlos
// tiraría el trabajo de una descarga que iba a continuar.
//
// Cuándo: al arrancar una descarga, como máximo una vez cada
// [intervaloLimpieza] por carpeta, y nunca sobre archivos recién
// escritos (podrían estar en vuelo en este instante).
//
// Se conecta con: orchestrator_download.go (llama a limpiarRestosDescarga).
// Parte del flujo: descarga de audio a disco.
// ─────────────────────────────────────────────────────────────

package download

import (
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// intervaloLimpieza evita recorrer la carpeta en cada canción de un álbum.
const intervaloLimpieza = 10 * time.Minute

// antiguedadMinima protege a los archivos que se están escribiendo ahora
// mismo: un compañero de carrera puede estar bajando en este instante.
const antiguedadMinima = 5 * time.Minute

var (
	limpiezaMu       sync.Mutex
	ultimaLimpiezaEn = map[string]time.Time{}
)

// esRestoInservible reporta si [nombre] es un temporal que ya no puede
// reanudarse ni convertirse en la descarga pedida.
func esRestoInservible(nombre string) bool {
	switch {
	case strings.HasPrefix(nombre, prefijoParalelo):
		return true
	case strings.Contains(nombre, tagsSufijo):
		return true
	case filepath.Ext(nombre) == ".partial":
		return true
	}
	return false
}

// limpiarRestosDescarga borra de [dir] los restos inservibles y devuelve
// cuántos archivos eliminó. Se salta los directorios (la caché de
// streaming vive dentro) y los archivos demasiado nuevos.
func limpiarRestosDescarga(dir string) int {
	if dir == "" {
		return 0
	}
	entradas, err := os.ReadDir(dir)
	if err != nil {
		return 0
	}
	limite := time.Now().Add(-antiguedadMinima)
	borrados := 0
	for _, e := range entradas {
		if e.IsDir() || !esRestoInservible(e.Name()) {
			continue
		}
		info, ierr := e.Info()
		if ierr != nil || info.ModTime().After(limite) {
			continue
		}
		if os.Remove(filepath.Join(dir, e.Name())) == nil {
			borrados++
		}
	}
	return borrados
}

// limpiarRestosSiCorresponde aplica el intervalo por carpeta: recorre la
// carpeta una vez cada [intervaloLimpieza] en vez de una vez por canción.
func limpiarRestosSiCorresponde(dir string) {
	if dir == "" {
		return
	}
	limpiezaMu.Lock()
	if ultima, ok := ultimaLimpiezaEn[dir]; ok && time.Since(ultima) < intervaloLimpieza {
		limpiezaMu.Unlock()
		return
	}
	ultimaLimpiezaEn[dir] = time.Now()
	limpiezaMu.Unlock()
	limpiarRestosDescarga(dir)
}
