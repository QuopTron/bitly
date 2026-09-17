// ─────────────────────────────────────────────────────────────
// sitios_flac_http.go — Plomería HTTP de los sitios raspables de FLAC:
// sesión con cookies, GET/POST de navegador, espera del trabajo de
// descarga y armado del detalle legible de un fallo.
//
// Por qué va aparte: el protocolo de cada sitio (sitios_flac_superflac.go)
// se lee mucho mejor sin las cabeceras de por medio, y esta plomería es la
// misma para cualquier sitio que se sume después.
//
// Se conecta con: sitios_flac_superflac.go.
// Parte del flujo: rescate de FLAC por descarga (no streaming).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"fmt"
	"html"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"strings"
	"time"
)

// nuevaSesionSitio arma un cliente con su propio frasco de cookies y un
// User-Agent de navegador: el token anti-CSRF viaja atado a la sesión y el
// sitio rechaza clientes desconocidos.
func nuevaSesionSitio() (*http.Client, error) {
	frasco, err := cookiejar.New(nil)
	if err != nil {
		return nil, err
	}
	return &http.Client{Timeout: timeoutSitio, Jar: frasco}, nil
}

// pedirSitio hace un GET de navegador (el sitio responde una página completa o
// un fragmento según la cabecera htmx, y acá sirven las dos).
func pedirSitio(sesion *http.Client, destino string) (string, error) {
	req, err := http.NewRequest(http.MethodGet, destino, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "text/html,application/xhtml+xml,*/*")
	req.Header.Set("Accept-Language", "es-ES,es;q=0.9,en;q=0.8")
	req.Header.Set("HX-Request", "true")
	resp, err := sesion.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	cuerpo, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return "", err
	}
	if resp.StatusCode >= 400 {
		return "", fmt.Errorf("el sitio respondió %d", resp.StatusCode)
	}
	return string(cuerpo), nil
}

// pedirDescargaSitio encola la descarga del candidato y devuelve la URL del
// trabajo que hay que consultar.
func pedirDescargaSitio(sesion *http.Client, base string, c candidatoSitio, calidad string) (string, error) {
	formulario := url.Values{
		"_token":        {c.token},
		"music_url":     {c.musicURL},
		"resource_kind": {c.tipo},
		"quality":       {calidad},
	}
	if formulario.Get("resource_kind") == "" {
		formulario.Set("resource_kind", "track")
	}
	req, err := http.NewRequest(http.MethodPost, base+"/downloads?inline=1",
		strings.NewReader(formulario.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "text/html,*/*")
	req.Header.Set("HX-Request", "true")
	resp, err := sesion.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	cuerpo, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return "", err
	}
	if m := reTrabajoSitio.FindStringSubmatch(string(cuerpo)); m != nil {
		return html.UnescapeString(m[1]), nil
	}
	return "", fmt.Errorf("el sitio no aceptó la descarga: %s", detalleSitio(cuerpo))
}

// esperarEnlaceSitio consulta el trabajo hasta que publica el enlace firmado
// del archivo (o hasta agotar la espera).
func esperarEnlaceSitio(sesion *http.Client, trabajo string) (string, error) {
	fin := time.Now().Add(esperaEnlaceSitio)
	var detalle string
	for time.Now().Before(fin) {
		time.Sleep(pasoConsultaSitio)
		pagina, err := pedirSitio(sesion, trabajo)
		if err != nil {
			detalle = err.Error()
			continue
		}
		if m := reArchivoSitio.FindStringSubmatch(pagina); m != nil {
			return html.UnescapeString(m[1]), nil
		}
		detalle = detalleSitio([]byte(pagina))
	}
	return "", fmt.Errorf("el sitio no terminó la descarga (%s)", detalle)
}
