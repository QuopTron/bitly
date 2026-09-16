// ─────────────────────────────────────────────────────────────
// qobuz_archivo.go — Del id de Qobuz a la URL de audio, con VERIFICACIÓN
// del formato que Qobuz entrega de verdad.
//
// Lo que se midió contra la API real (2026-09-16), y que este archivo
// respeta:
//
//   - Qobuz NO indexa ISRC: /catalog/search?query=<ISRC> devuelve 0
//     resultados. El camino real es buscar por NOMBRE y confirmar el ISRC
//     del resultado (ver qobuz_busqueda.go).
//   - Sin token de suscriptor, Qobuz responde 200 con una URL pero
//     DEGRADADA: host streaming-qobuz-std, mime audio/mpeg y
//     restrictions=[{code:"UserUnauthenticated"}] — o sea MP3 320 aunque
//     se pida FLAC. Por eso se PIDE y se VERIFICA: nunca se declara sin
//     pérdida algo que Qobuz sirvió en MP3 (el usuario oiría MP3).
//   - Con un token de suscriptor (qobuz_user_token) el formato sin pérdida
//     sí sale del CDN de Qobuz.
//
// Se conecta con: qobuz_firmado.go (llamada firmada) y resolucion.go.
// Parte del flujo: rescate de audio por ISRC (reproducción y descarga).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

// formatosQobuz mapea la calidad pedida a un format_id de Qobuz.
//
//	"6" = FLAC (requiere token de suscriptor; sin él Qobuz degrada a MP3)
//	"5" = MP3 320 (funciona sin token: verificado)
//
// Un ajuste explícito (qobuz_format_id) tiene la última palabra.
func (c *Client) formatoPara(formatoPedido string) (formatID string, exigirSinPerdida bool) {
	c.mu.RLock()
	override := c.qobuzFormato
	c.mu.RUnlock()
	if override != "" && override != qobuzFormatoFLAC {
		return override, false
	}
	if formatoPedido == "FLAC" {
		return "6", true
	}
	return "5", false
}

// respuestaFileURL es lo que Qobuz devuelve en /track/getFileUrl. Los campos de
// formato NO son decorativos: son la única forma de saber si lo que llegó es el
// sin pérdida pedido o el MP3 de un usuario sin sesión.
type respuestaFileURL struct {
	URL      string  `json:"url"`
	MimeType string  `json:"mime_type"`
	BitDepth int     `json:"bit_depth"`
	Duration float64 `json:"duration"`
	// Sample: Qobuz marca así la URL de muestra de 30s (cuenta sin suscripción
	// sobre un track que no puede servir entero). Es el dato que evita servir
	// un clip como si fuera la canción.
	Sample       bool `json:"sample"`
	Restrictions []struct {
		Code string `json:"code"`
	} `json:"restrictions"`
}

// esURLDeMuestra delata una muestra por la propia URL (los espejos y el CDN de
// Qobuz la nombran así cuando degradan).
func esURLDeMuestra(u string) bool {
	m := strings.ToLower(u)
	for _, marca := range []string{"/sample", "sample/", "sample?", "preview", "/30s", "_30s"} {
		if strings.Contains(m, marca) {
			return true
		}
	}
	return false
}

// autenticacionRequerida reporta la marca con la que Qobuz dice "esta URL es de
// usuario no autenticado" (o sea: degradada a MP3).
func (r respuestaFileURL) autenticacionRequerida() bool {
	for _, restr := range r.Restrictions {
		if strings.EqualFold(restr.Code, "UserUnauthenticated") {
			return true
		}
	}
	return false
}

// esSinPerdida reporta si la respuesta es FLAC de verdad.
func (r respuestaFileURL) esSinPerdida() bool {
	return strings.Contains(strings.ToLower(r.MimeType), "flac")
}

// validarFormato rechaza la respuesta cuando se pidió sin pérdida y Qobuz
// entregó MP3. Sin esto el canal "resolvería" una canción en FLAC con un MP3 y
// el usuario creería que está oyendo sin pérdida.
func validarFormato(r respuestaFileURL, exigirSinPerdida bool) error {
	if !strings.HasPrefix(r.URL, "http") {
		return fmt.Errorf("qobuz-firmado: sin URL de audio")
	}
	// Muestra de 30s: se rechaza SIEMPRE (también en MP3). Reproducir 30s y
	// cortar es peor que fallar y dejar que los espejos/la descarga real
	// entreguen la canción completa.
	if r.Sample || esURLDeMuestra(r.URL) {
		return fmt.Errorf("qobuz-firmado: Qobuz devolvió una muestra corta, no la canción")
	}
	if !exigirSinPerdida {
		return nil
	}
	if r.esSinPerdida() {
		return nil
	}
	if r.autenticacionRequerida() {
		return fmt.Errorf("qobuz-firmado: Qobuz pidió sesión (sin token de suscriptor solo entrega MP3)")
	}
	return fmt.Errorf("qobuz-firmado: Qobuz entregó %q en vez del FLAC pedido", r.MimeType)
}

// esIDNumerico reporta si [id] es un id de pista de Qobuz (numérico) y no un
// ISRC. Los ids de Qobuz tienen 6-12 dígitos; los ISRC siempre tienen letras.
func esIDNumerico(id string) bool {
	if len(id) < 5 || len(id) > 12 {
		return false
	}
	_, err := strconv.Atoi(id)
	return err == nil
}

// resolverQobuzFirmado devuelve la URL de audio para un id de pista de Qobuz o
// para un ISRC. Con id numérico es UNA sola petición (el camino rápido de la
// reproducción); con ISRC se intenta la búsqueda por texto, que Qobuz no indexa
// por ISRC pero puede devolver una pista cuyo ISRC coincida.
func (c *Client) resolverQobuzFirmado(id, formatoPedido string) (string, error) {
	base, _, _, _, _, ok := c.qobuzCredenciales()
	if !ok {
		return "", fmt.Errorf("qobuz-firmado: sin credenciales configuradas")
	}
	formatID, exigirSinPerdida := c.formatoPara(formatoPedido)

	ctx, cancel := context.WithTimeout(context.Background(), presupuestoQobuz)
	defer cancel()

	trackID := strings.TrimSpace(id)
	if !esIDNumerico(trackID) {
		encontrado, err := c.trackIDPorISRC(ctx, base, trackID)
		if err != nil {
			return "", err
		}
		trackID = encontrado
	}

	params := map[string]string{
		"format_id": formatID,
		"intent":    "stream",
		"track_id":  trackID,
	}
	var resp respuestaFileURL
	if err := c.pedirQobuz(ctx, base, "/track/getFileUrl", params, &resp); err != nil {
		return "", err
	}
	if err := validarFormato(resp, exigirSinPerdida); err != nil {
		return "", err
	}
	return resp.URL, nil
}

// trackIDPorISRC busca un id de pista cuyo ISRC coincida EXACTAMENTE. La
// búsqueda de Qobuz es de texto, así que devuelve parecidos de nombre: aceptar
// el primero sería servir otra grabación.
func (c *Client) trackIDPorISRC(ctx context.Context, base, isrc string) (string, error) {
	params := map[string]string{"query": isrc, "limit": strconv.Itoa(maxPistasQobuz), "offset": "0"}
	var resp struct {
		Tracks struct {
			Items []pistaQobuz `json:"items"`
		} `json:"tracks"`
	}
	if err := c.pedirQobuz(ctx, base, "/catalog/search", params, &resp); err != nil {
		return "", err
	}
	for _, item := range resp.Tracks.Items {
		if strings.EqualFold(strings.TrimSpace(item.ISRC), isrc) {
			if id := idATexto(item.ID); id != "" {
				return id, nil
			}
		}
	}
	return "", fmt.Errorf("qobuz-firmado: sin pista con el ISRC %s", isrc)
}

// idATexto normaliza el id de Qobuz, que llega como número o como texto.
func idATexto(v any) string {
	switch t := v.(type) {
	case string:
		return strings.TrimSpace(t)
	case float64:
		return strconv.FormatInt(int64(t), 10)
	case json.Number:
		return t.String()
	}
	return ""
}
