// ─────────────────────────────────────────────────────────────
// mejora_flac.go — Decide y valida la "mejora silenciosa a FLAC":
// cuándo corresponde buscar el sin pérdida de una canción ya bajada
// (calidad pedida sin pérdida + el ganador fue con pérdida), qué
// fuentes pueden entregarlo sin cuentas propias y si el archivo que
// llegó es FLAC de verdad y de la duración correcta.
//
// Por qué existe: la entrega rápida (InnerTube/YouTube) no es FLAC y
// los catálogos sin sesión tampoco. En vez de hacer esperar la
// reproducción/descarga a las fuentes sin pérdida (que tardan), se
// entrega lo que hay y se mejora DESPUÉS, en segundo plano. La parte
// pura vive acá para poder fijarla con tests; la cola y el worker en
// orchestrator_mejora_flac.go.
//
// Se conecta con: orchestrator_mejora_flac.go (cola y worker) y
// orchestrator_download.go (hook al terminar una descarga).
// Parte del flujo: descargas (post-entrega, sin tocar el tiempo).
// ─────────────────────────────────────────────────────────────

package download

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/audioguard"
)

// proveedoresSinPerdida son los proveedores que entregan audio sin pérdida
// real. Si el ganador de una descarga está acá, no hay nada que mejorar.
//
// Duplica la lista de internal/streaming/play_types.go a propósito: importar
// ese paquete desde download crearía un ciclo, y acá la lista se usa para
// DECIDIR una descarga, no para ordenar una carrera de reproducción.
var proveedoresSinPerdida = map[string]bool{
	"flac-rescue": true, "tidal-hifi": true, "internetarchive": true, "soulseek": true,
	"deezer": true, "deezer-web": true, "qobuz": true, "qobuz-web": true,
	"tidal": true, "tidal-web": true, "amazon": true, "amazon-web": true,
	"apple-music": true,
}

// proveedoresFLACMejora son las fuentes que pueden traer el FLAC REAL sin
// cuentas propias, en el orden en que se prueban. Soulseek va último porque su
// búsqueda P2P es la más lenta y la única que depende de que haya un par con el
// archivo.
// Orden de intento: primero el que resuelve en UNA petición (los sitios
// raspables, dentro de flac-rescue), después el canal Tidal, que entrega el
// FLAC exacto por ISRC pero arma la canción segmento a segmento (más
// peticiones), y al final lo abierto y lo P2P.
var proveedoresFLACMejora = []string{"flac-rescue", "tidal-hifi", "internetarchive", "soulseek"}

// entregaSinPerdida reporta si [name] ya entrega audio sin pérdida.
func entregaSinPerdida(name string) bool { return proveedoresSinPerdida[name] }

// debeMejorarSinPerdida decide si vale la pena buscar el FLAC de una descarga
// que acaba de terminar. Devuelve la razón en texto (para el log) siempre.
//
// No se mejora cuando: el usuario no pidió sin pérdida, el archivo se quedó
// encriptado (lo maneja el decrypt del cliente), no hay archivo ni carpeta, no
// hay identidad con la que buscar (ISRC/título) o el ganador ya era sin
// pérdida.
func debeMejorarSinPerdida(req Request, res *Result) (bool, string) {
	if res == nil || !res.Success {
		return false, "la descarga no terminó bien"
	}
	if !quiereSinPerdida(req.Quality) {
		return false, "el usuario no pidió sin pérdida"
	}
	if entregaSinPerdida(res.Provider) {
		return false, "el ganador (" + res.Provider + ") ya entrega sin pérdida"
	}
	if res.Encrypted || res.ClientDecrypt {
		return false, "el archivo quedó encriptado para el decrypt del cliente"
	}
	if res.FilePath == "" || res.Local {
		return false, "no hay archivo propio que mejorar"
	}
	if req.OutputDir == "" && GlobalOutputDir() == "" {
		return false, "sin carpeta de descargas"
	}
	if strings.TrimSpace(req.ISRC) == "" && strings.TrimSpace(req.Title) == "" {
		return false, "sin ISRC ni título para buscar el FLAC"
	}
	return true, "se busca el sin pérdida en segundo plano"
}

// esFLACSinPerdida valida que [ruta] sea un FLAC de verdad (no un MP3 con
// extensión cambiada ni una muestra). Devuelve el motivo cuando no lo es.
func esFLACSinPerdida(ruta string) (bool, string) {
	veredicto := audioguard.Revisar(ruta)
	if !veredicto.OK {
		return false, "no es audio reproducible: " + veredicto.Motivo
	}
	if !strings.EqualFold(veredicto.Formato, "flac") {
		return false, "el archivo llegó como " + veredicto.Formato + ", no FLAC"
	}
	return true, ""
}

// rutaFLACPara devuelve la ruta final del FLAC de una canción: el MISMO nombre
// del archivo actual, con la extensión cambiada. Así el reemplazo no deja dos
// archivos y las rutas de la app siguen siendo predecibles.
func rutaFLACPara(rutaActual string) string {
	ext := filepath.Ext(rutaActual)
	return strings.TrimSuffix(rutaActual, ext) + ".flac"
}

// duracionFLACMs lee la duración de un FLAC desde su cabecera STREAMINFO
// (sample rate + total de samples). 0 = no se pudo leer.
//
// Para qué: la verificación de duración es la que evita dar por buena la
// grabación equivocada (un directo o un corte con el mismo nombre). Sin dato
// del catálogo no se verifica nada y queda igual.
func duracionFLACMs(ruta string) int {
	f, err := os.Open(ruta)
	if err != nil {
		return 0
	}
	defer f.Close()
	// 4 bytes "fLaC" + cabecera del bloque STREAMINFO (4) + sus 34 bytes.
	cabecera := make([]byte, 4+4+34)
	if _, err := f.Read(cabecera); err != nil {
		return 0
	}
	if string(cabecera[:4]) != "fLaC" {
		return 0
	}
	info := cabecera[8:]
	// sample_rate: 20 bits que arrancan en el byte 10 (después de los 64 bits
	// de min/max block size y min/max frame size).
	crudo := binary.BigEndian.Uint64(info[10:18])
	sampleRate := int(crudo >> 44 & 0xFFFFF)
	totalSamples := int(crudo & 0xFFFFFFFFF)
	if sampleRate <= 0 || totalSamples <= 0 {
		return 0
	}
	return int(int64(totalSamples) * 1000 / int64(sampleRate))
}
