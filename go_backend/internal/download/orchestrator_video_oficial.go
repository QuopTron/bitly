// ─────────────────────────────────────────────────────────────
// orchestrator_video_oficial.go — Último recurso del orquestador.
//
// Cuando TODAS las fuentes fallaron, se le pregunta a Last.fm cuál es el
// video OFICIAL de esa pista (el que publicó el propio artista en su
// canal) y se pide el audio por ESE id.
//
// Por qué ayuda: la causa más común de "fallaron todas" es que la
// búsqueda por nombre del proveedor de turno no encontró la canción (o
// encontró otra). Con el id oficial no hay búsqueda: se pide el video
// exacto. La respuesta se verifica antes (nombre normalizado igual y, si
// hay, duración dentro de la tolerancia), así que no entra cualquier cosa.
//
// Costo: una consulta como máximo por descarga fallida, cacheada 12 h y
// con el cliente en pausa si el sitio devolvió su desafío. Nunca retrasa
// el camino que ya funcionó.
// ─────────────────────────────────────────────────────────────

package download

import (
	"log"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider/lastfm"
)

// intentarConVideoOficial hace el intento final y devuelve nil si no hay
// identidad fiable (o si no queda proveedor nativo de YouTube registrado).
func (o *Orchestrator) intentarConVideoOficial(req Request, outDir string, st *fallbackState) *Result {
	if strings.TrimSpace(req.Title) == "" || strings.TrimSpace(req.Artist) == "" {
		return nil
	}
	p := o.providers.Get("youtube")
	if p == nil {
		// Sin proveedor nativo de YouTube (una extensión lo reemplazó) este
		// rescate no aplica: la extensión no acepta el id "yt:" tal cual.
		return nil
	}
	pista, err := lastfm.Compartido().MejorCoincidencia(
		req.Artist, req.Album, req.Title, req.DurationMS,
	)
	if err != nil {
		log.Printf("[lastfm] sin identidad para %q: %v", req.Title, err)
		return nil
	}
	if pista == nil || pista.YouTubeID == "" {
		return nil
	}
	log.Printf(
		"[lastfm] último recurso: video oficial %s de %q — %s",
		pista.YouTubeID, pista.Nombre, pista.Artistas,
	)
	// El proveedor nativo de YouTube recibe el id con su prefijo ("yt:<id>").
	res := o.attemptNativeDownload(
		req, "youtube", p, "yt:"+pista.YouTubeID, pista.Nombre, pista.Artistas, outDir,
	)
	if res == nil || !res.Success {
		if res != nil {
			st.registrarFallo("lastfm+youtube", res.Error)
		}
		return nil
	}
	return res
}
