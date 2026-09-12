package youtube

import "strings"

// splitLines splits NDJSON output into non-empty lines.
func splitLines(out string) []string {
	lines := strings.Split(out, "\n")
	result := make([]string, 0, len(lines))
	for _, l := range lines {
		if trimmed := strings.TrimSpace(l); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

// firstJSONLine extracts the first JSON line from yt-dlp output (may contain warnings).
func firstJSONLine(out string) string {
	for _, line := range splitLines(out) {
		if strings.HasPrefix(line, "{") {
			return line
		}
	}
	return ""
}

// nonEmpty returns the first non-empty string.
func nonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

// duracionMS convierte la duración de yt-dlp (SEGUNDOS) a milisegundos, que es
// la unidad de provider.TrackResult.Duration (json durationMs) en TODO el
// backend: las extensiones emiten duration_ms, duracionCoincide compara en ms y
// el feed serializa durationMs. Sin esta conversión YouTube reportaba 210 en vez
// de 210000, así que la verificación por duración rechazaba coincidencias
// correctas (y el feed mostraba "0:00").
func duracionMS(segundos int) int {
	if segundos <= 0 {
		return 0
	}
	return segundos * 1000
}
