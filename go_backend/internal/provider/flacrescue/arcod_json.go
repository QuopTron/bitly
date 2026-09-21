// ─────────────────────────────────────────────────────────────
// arcod_json.go — Plomería HTTP del canal arcod (ver arcod.go): un GET
// que devuelve el cuerpo JSON tal cual, con el Bearer opcional que
// habilita una instancia propia que exija sesión (arcod_acceso.go).
//
// Por qué aparte de sitios_flac_http.go: ese sirve a los sitios que
// responden páginas con formularios (y manda la cabecera htmx); acá se
// habla con una API JSON. El cuerpo se devuelve también cuando la
// respuesta es un error, porque es lo que permite decir POR QUÉ falló
// el canal en vez de un genérico "no se pudo".
//
// Se conecta con: arcod.go, arcod_cuota.go y arcod_acceso.go.
// Parte del flujo: rescate de FLAC por stream y por descarga.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"fmt"
	"io"
	"net/http"
)

// pedirArcod hace el GET del canal con el Bearer configurado (si lo hay). Es el
// único camino por el que salen las peticiones del canal, así que una instancia
// propia con sesión obligatoria funciona igual que la pública.
func (c *Client) pedirArcod(destino string) ([]byte, error) {
	cabeceras := map[string]string{}
	if token := c.tokenArcod(); token != "" {
		cabeceras["Authorization"] = "Bearer " + token
	}
	return pedirJSON(c.http, destino, cabeceras)
}

// pedirJSON hace un GET y devuelve el cuerpo crudo. El error lleva el
// código de la respuesta y el cuerpo se devuelve igual para poder
// interpretarlo (un 4xx del canal suele traer el motivo en JSON).
// [cabeceras] es opcional (p.ej. el Bearer de una instancia propia).
func pedirJSON(sesion *http.Client, destino string, cabeceras map[string]string) ([]byte, error) {
	req, err := http.NewRequest(http.MethodGet, destino, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")
	for clave, valor := range cabeceras {
		if valor != "" {
			req.Header.Set(clave, valor)
		}
	}
	resp, err := sesion.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	datos, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode >= 400 {
		return datos, fmt.Errorf("el canal respondió %d", resp.StatusCode)
	}
	return datos, nil
}
