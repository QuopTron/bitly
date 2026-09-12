// ─────────────────────────────────────────────────────────────
// resolucion.go — Resolución de un ISRC a URL de audio: cascada de
// formatos (FLAC → MP3_320 → MP3_128) por todos los espejos, con
// presupuesto de tiempo, caché y errores legibles.
//
// Se conecta con: client.go (configuración) y el orquestador de
// descarga/streaming, que llama a GetStreamURL.
// Parte del flujo: interior del rescate de audio (no se usa solo).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// errNoCatalogo es el error de los métodos que flac-rescue no soporta.
func errNoCatalogo(qué string) error {
	return fmt.Errorf("flac-rescue: %s no soportada (solo resuelve audio por ISRC)", qué)
}

// normalizarISRC limpia y valida el ISRC. Acepta el prefijo
// "<proveedor>:" que a veces traen los ids del feed.
func normalizarISRC(id string) string {
	if i := strings.LastIndex(id, ":"); i >= 0 {
		id = id[i+1:]
	}
	id = strings.ToUpper(strings.TrimSpace(id))
	if len(id) < 5 {
		return ""
	}
	return id
}

// normalizarFormato mapea la calidad pedida a un formato del contrato.
func normalizarFormato(v string) string {
	switch strings.ToUpper(strings.TrimSpace(v)) {
	case "FLAC", "LOSSLESS", "HI_RES", "HIRES", "24", "16":
		return "FLAC"
	case "MP3_320", "320", "HIGH":
		return "MP3_320"
	case "MP3_128", "128", "LOW":
		return "MP3_128"
	default:
		return ""
	}
}

// parseMirrors acepta "https://a,https://b" (o saltos de línea) y
// también un array JSON ["https://a","https://b"].
func parseMirrors(raw string) []string {
	raw = strings.TrimSpace(raw)
	var lista []string
	if strings.HasPrefix(raw, "[") {
		_ = json.Unmarshal([]byte(raw), &lista)
	} else {
		lista = strings.FieldsFunc(raw, func(r rune) bool {
			return r == ',' || r == '\n' || r == '\r' || r == ' '
		})
	}
	limpios := make([]string, 0, len(lista))
	vistos := map[string]bool{}
	for _, m := range lista {
		m = strings.TrimRight(strings.TrimSpace(m), "/")
		if len(m) < 9 || !strings.HasPrefix(m, "http") || vistos[m] {
			continue
		}
		vistos[m] = true
		limpios = append(limpios, m)
	}
	return limpios
}

// calidadAFormatos arma la cascada de formatos a intentar, del mejor
// al más compatible. Así una fuente que ya no tiene FLAC (como le pasó
// a los espejos de Deezer) igual entrega MP3 en vez de fallar.
func (c *Client) calidadAFormatos(quality string) []string {
	c.mu.RLock()
	preferido := c.formato
	c.mu.RUnlock()

	if pedido := normalizarFormato(quality); pedido != "" {
		preferido = pedido
	}
	switch preferido {
	case "MP3_128":
		return []string{"MP3_128"}
	case "MP3_320":
		return []string{"MP3_320", "MP3_128"}
	default: // FLAC
		return []string{"FLAC", "MP3_320", "MP3_128"}
	}
}

// resolverPorISRC recorre formatos y espejos hasta encontrar audio.
// Cachea el resultado positivo y respeta el presupuesto total.
func (c *Client) resolverPorISRC(isrc string, formatos []string) (string, string, error) {
	c.mu.RLock()
	espejos := append([]string(nil), c.mirrors...)
	c.mu.RUnlock()
	if len(espejos) == 0 {
		return "", "", errors.New("flac-rescue: sin espejos configurados")
	}

	claveCache := isrc + "@" + strings.Join(formatos, ",")
	c.cacheMu.Lock()
	if e, ok := c.cache[claveCache]; ok && time.Now().Before(e.expires) {
		c.cacheMu.Unlock()
		return e.url, e.mirror, nil
	}
	c.cacheMu.Unlock()

	fin := time.Now().Add(presupuestoTotal)
	var ultimo error
	for _, formato := range formatos {
		for _, espejo := range espejos {
			if time.Now().After(fin) {
				return "", "", fmt.Errorf("flac-rescue: tiempo agotado (%v)", ultimo)
			}
			audioURL, err := c.resolverEnEspejo(espejo, isrc, formato)
			if err != nil {
				ultimo = err
				continue
			}
			c.guardarCache(claveCache, audioURL, espejo)
			return audioURL, espejo, nil
		}
	}
	if ultimo == nil {
		ultimo = errors.New("sin respuesta de los espejos")
	}
	return "", "", fmt.Errorf("flac-rescue: %v", ultimo)
}

// guardarCache memoriza un acierto (y acota el tamaño de la caché).
func (c *Client) guardarCache(clave, url, espejo string) {
	c.cacheMu.Lock()
	defer c.cacheMu.Unlock()
	if len(c.cache) > maxCache {
		c.cache = map[string]cacheEntry{}
	}
	c.cache[clave] = cacheEntry{url: url, mirror: espejo, expires: time.Now().Add(cacheTTL)}
}

// resolverEnEspejo pregunta a UN espejo por el ISRC con un formato.
// Acepta dos respuestas: audio binario directo (lo ideal, se devuelve
// la propia URL) o JSON {"url": "..."} (se devuelve esa URL).
func (c *Client) resolverEnEspejo(espejo, isrc, formato string) (string, error) {
	base := strings.TrimRight(espejo, "/")
	endpoint := base + "/stream/?isrc=" + url.QueryEscape(isrc) +
		"&format=" + url.QueryEscape(formato)

	c.mu.RLock()
	origin := c.origin
	c.mu.RUnlock()

	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return "", err
	}
	// Origin/Referer: los espejos de la familia monochrome responden
	// 403 "requests must come from an allowed site" sin esto.
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "*/*")
	req.Header.Set("Origin", origin)
	req.Header.Set("Referer", origin+"/")

	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("%s: %v", base, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return "", fmt.Errorf("%s (%d): %s", base, resp.StatusCode, mensajeEspejo(resp))
	}
	// Caso 1: el espejo sirve el audio directo.
	if ct := resp.Header.Get("Content-Type"); strings.HasPrefix(ct, "audio/") {
		return endpoint, nil
	}
	// Caso 2: JSON con la URL de audio.
	var payload map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return "", fmt.Errorf("%s: respuesta no interpretada", base)
	}
	if u := buscarURL(payload); u != "" {
		return u, nil
	}
	return "", fmt.Errorf("%s: sin URL de audio en la respuesta", base)
}

// mensajeEspejo extrae el "error" del JSON del espejo para poder decirle
// al usuario POR QUÉ falló (p.ej. "All Deezer accounts are dead").
func mensajeEspejo(resp *http.Response) string {
	var payload struct {
		Error string `json:"error"`
		Det   string `json:"detail"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return "sin detalle"
	}
	if payload.Error != "" {
		return payload.Error
	}
	if payload.Det != "" {
		return payload.Det
	}
	return "sin detalle"
}

// buscarURL busca la URL de audio en las claves que usan los espejos.
func buscarURL(payload map[string]any) string {
	for _, k := range []string{"url", "audioUrl", "streamUrl", "OriginalTrackUrl", "directURL", "link"} {
		if v, ok := payload[k].(string); ok && strings.HasPrefix(v, "http") {
			return v
		}
	}
	if data, ok := payload["data"].(map[string]any); ok {
		return buscarURL(data)
	}
	return ""
}
