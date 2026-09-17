// ─────────────────────────────────────────────────────────────
// sitios_flac_detalle.go — Detalle legible de una respuesta de sitio
// raspable de FLAC: saca el texto del HTML para poder decir POR QUÉ
// falló, en vez de "no se pudo descargar".
//
// Se conecta con: sitios_flac_http.go (espera del trabajo de descarga).
// Parte del flujo: rescate de FLAC por descarga (no streaming).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"encoding/json"
	"html"
	"regexp"
	"strings"
)

// detalleSitio saca el texto legible de la respuesta del sitio para poder
// decir POR QUÉ falló, en vez de "no se pudo".
func detalleSitio(cuerpo []byte) string {
	if len(cuerpo) == 0 {
		return "sin respuesta"
	}
	var payload struct {
		Error   string `json:"error"`
		Message string `json:"message"`
	}
	if json.Unmarshal(cuerpo, &payload) == nil {
		if payload.Error != "" {
			return payload.Error
		}
		if payload.Message != "" {
			return payload.Message
		}
	}
	texto := strings.Join(strings.Fields(stripTags(string(cuerpo))), " ")
	if texto == "" {
		return "sin detalle"
	}
	if len(texto) > 160 {
		texto = texto[:160]
	}
	return texto
}

var reEtiqueta = regexp.MustCompile(`<[^>]*>`)

// stripTags deja solo el texto de un fragmento HTML.
func stripTags(s string) string { return html.UnescapeString(reEtiqueta.ReplaceAllString(s, " ")) }
