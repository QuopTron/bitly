// ─────────────────────────────────────────────────────────────
// verificacion_duracion.go — Guard anti-preview de las DESCARGAS: una
// fuente puede devolver un clip de 30s (preview) de la canción pedida.
// Antes eso se aceptaba como descarga buena y el usuario terminaba con
// un archivo corto. Acá, si el archivo descargado dura una fracción de
// lo que el catálogo declara, la candidata se RECHAZA y la carrera de
// proveedores sigue con la siguiente.
//
// Se conecta con: orchestrator_consume.go (rechaza la candidata) y
// internal/audio (lee la duración real del archivo).
// Parte del flujo: descarga (verificación de la candidata ganadora).
// ─────────────────────────────────────────────────────────────

package download

import (
	"log"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/audio"
)

// fraccionDuracionMinima es la proporción mínima que un archivo debe durar
// respecto de la canción pedida. Un preview/clip queda muy por debajo.
//
// Es holgada a propósito: existen ediciones (radio edit, versión de álbum vs
// sencillo) que legítimamente duran bastante menos, y rechazar una descarga
// buena es peor que aceptar un clip — de un clip el usuario se da cuenta y
// vuelve a intentar; de una descarga buena rechazada, no.
const fraccionDuracionMinima = 0.5

// duracionMinimaCatalogoMs: por debajo de esto no se aplica el guard (clips
// promocionales, intros y tracks cortos legítimos existen).
const duracionMinimaCatalogoMs = 60000

// esDuracionPlausible reporta si un archivo descargado dura lo suficiente como
// para ser la canción pedida y no un preview.
//
// Devuelve true (aceptar) salvo que PUEDA CONFIRMAR que el archivo es un clip.
// "Confirmar" exige que la duración sea REAL (meta.DuracionExacta): cuando era
// una estimación por tamaño ÷ bitrate supuesto, una canción completa de 200s se
// medía como 87s y este guard tiraba descargas buenas dejando al usuario sin
// música. Sin dato fiable no se juzga (mismo criterio que un archivo encriptado
// que se descifra más adelante).
func esDuracionPlausible(filePath string, duracionCatalogoMs int) bool {
	if filePath == "" || duracionCatalogoMs < duracionMinimaCatalogoMs {
		return true
	}
	meta, err := audio.ReadFileMetadata(filePath)
	if err != nil || meta == nil || meta.DurationMs <= 0 {
		return true
	}
	if !meta.DuracionExacta {
		// Duración estimada: no alcanza para rechazar nada.
		return true
	}
	limite := int(float64(duracionCatalogoMs) * fraccionDuracionMinima)
	if meta.DurationMs >= limite {
		return true
	}
	log.Printf("[download] candidata rechazada por preview: %s dura %dms de %dms esperados (%s)",
		filePath, meta.DurationMs, duracionCatalogoMs, strings.TrimSpace(meta.Format))
	return false
}
