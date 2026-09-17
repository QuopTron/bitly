// ─────────────────────────────────────────────────────────────
// salud.go — Lista VIVA de proxies Tidal: el health-check público publica
// qué instancias de hifi-api están activas ahora, y este archivo la trae
// solo cuando las bases de fábrica dejaron de responder.
//
// Por qué existe: las APIs de este tipo son gratuitas y se caen o se mudan.
// En vez de tener dos direcciones fijas en el código, el canal se recupera
// solo: si las fijas fallan, se pregunta por las vivas y se reintenta una
// vez. La lista se recuerda [ttlSalud] para no golpear el health-check en
// cada canción (es un servicio ajeno y no hay por qué castigarlo).
//
// Se conecta con: client.go (pedir, listaDeBases).
// Parte del flujo: descarga (rescate de FLAC exacto).
// ─────────────────────────────────────────────────────────────

package tidalhifi

import (
	"encoding/json"
	"net/http"
	"time"
)

// saludProxy es el health-check público con la lista de proxies Tidal vivos.
const saludProxy = "https://proxy.odskyler.workers.dev/health"

// ttlSalud es cuánto se recuerda la lista antes de volver a leerla.
const ttlSalud = 10 * time.Minute

// refrescarSalud relee la lista de proxies vivos y devuelve cuántos hay.
// Best-effort: si el health-check no responde, se conserva la lista anterior
// (y se anota la hora para no insistir en cada canción).
func (c *Client) refrescarSalud() int {
	c.mu.RLock()
	reciente := time.Since(c.saludLeida) < ttlSalud
	c.mu.RUnlock()
	if reciente {
		c.mu.RLock()
		defer c.mu.RUnlock()
		return len(c.salud)
	}

	vivos := leerProxiesVivos(c)
	c.mu.Lock()
	if len(vivos) > 0 {
		c.salud = vivos
	}
	c.saludLeida = time.Now()
	c.mu.Unlock()
	return len(vivos)
}

// leerProxiesVivos consulta el health-check y devuelve las URLs que están
// respondiendo 200 en ese momento.
func leerProxiesVivos(c *Client) []string {
	cuerpo, err := c.pedirCrudo(saludProxy)
	if err != nil {
		return nil
	}
	var salud struct {
		Activos []struct {
			URL    string `json:"url"`
			Estado int    `json:"status"`
		} `json:"active"`
	}
	if err := json.Unmarshal(cuerpo, &salud); err != nil {
		return nil
	}
	vivos := make([]string, 0, len(salud.Activos))
	for _, p := range salud.Activos {
		if p.URL != "" && p.Estado == http.StatusOK {
			vivos = append(vivos, p.URL)
		}
	}
	return vivos
}
