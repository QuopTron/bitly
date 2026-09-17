// ─────────────────────────────────────────────────────────────
// orchestrator_mejora_flac_reemplazo.go — Reemplazo del archivo con
// pérdida por el FLAC: deja el FLAC con el MISMO nombre (para no dejar
// dos archivos ni romper las rutas guardadas), le escribe etiquetas y
// carátula, borra el anterior y republica la ruta en el tracker.
//
// Por qué publica la ruta: la app escucha el progreso de la descarga por
// itemID; al cambiar el path en el tracker, su próximo poll re-apunta la
// fila de la BD y el reproductor a la canción en FLAC.
//
// Se conecta con: orchestrator_mejora_flac_bajar.go (lo llama al ganar).
// Parte del flujo: descargas (después de entregar).
// ─────────────────────────────────────────────────────────────

package download

import (
	"fmt"
	"os"
)

// reemplazarPorFLAC deja el FLAC con el nombre del archivo anterior, borra el
// archivo con pérdida y publica la ruta nueva en el tracker para que la app la
// tome en su próximo poll.
func (o *Orchestrator) reemplazarPorFLAC(t trabajoMejoraFLAC, rutaNueva, name string) error {
	destino := rutaFLACPara(t.rutaActual)
	if rutaNueva != destino {
		_ = os.Remove(destino)
		if err := os.Rename(rutaNueva, destino); err != nil {
			// Distinto volumen (raro): copiar y borrar el temporal.
			if errCopiar := copiarArchivo(rutaNueva, destino); errCopiar != nil {
				return fmt.Errorf("no se pudo mover el FLAC: %v", err)
			}
			_ = os.Remove(rutaNueva)
		}
	}
	// Etiquetas + carátula DENTRO del FLAC, como en cualquier descarga.
	o.etiquetarDescarga(&Result{FilePath: destino, Provider: name}, t.req)
	if t.rutaActual != destino {
		_ = os.Remove(t.rutaActual)
	}
	o.tracker.SetOutputPath(t.req.ItemID, destino)
	return nil
}

// abs es el valor absoluto de un int (evita importar math por una resta).
func abs(v int) int {
	if v < 0 {
		return -v
	}
	return v
}
