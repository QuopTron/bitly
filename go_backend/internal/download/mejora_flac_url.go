// ─────────────────────────────────────────────────────────────
// mejora_flac_url.go — Filtro por URL de la mejora a FLAC: descarta sin
// bajar nada las fuentes que ya delatan que no tienen el sin pérdida.
//
// Por qué: varias fuentes devuelven "algo reproducible" cuando el FLAC
// no existe (Internet Archive cae a su derivado MP3). Bajarlo para
// después rechazarlo gasta megas y tiempo del usuario en cada canción.
//
// Se conecta con: orchestrator_mejora_flac_bajar.go (lo llama antes de
// bajar) y mejora_flac.go (la validación final, que ya mira la firma del
// archivo: una extensión no es una garantía).
// Parte del flujo: descargas (mejora silenciosa a FLAC).
// ─────────────────────────────────────────────────────────────

package download

import (
	"net/url"
	"path/filepath"
	"strings"
)

// formatosConPerdida son las extensiones que delatan que una fuente NO tiene
// el sin pérdida (aunque diga que sí).
var formatosConPerdida = map[string]bool{
	".mp3": true, ".m4a": true, ".aac": true, ".ogg": true, ".opus": true,
	".wma": true, ".mp4": true, ".webm": true,
}

// urlPrometeSinPerdida mira la extensión de la URL antes de bajar nada. Una URL
// sin extensión (o de formato desconocido) devuelve true: se baja y decide la
// firma real del archivo.
func urlPrometeSinPerdida(rawURL string) (bool, string) {
	ruta := rawURL
	if u, err := url.Parse(rawURL); err == nil && u.Path != "" {
		ruta = u.Path
	}
	ext := strings.ToLower(filepath.Ext(ruta))
	if formatosConPerdida[ext] {
		return false, "la fuente ofrece " + ext + ", no FLAC"
	}
	return true, ""
}
