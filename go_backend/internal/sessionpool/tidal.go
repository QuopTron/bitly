// ─────────────────────────────────────────────────────────────
// tidal.go — Credenciales de Tidal: access token (Bearer).
//
// Cómo se valida: una llamada a /v1/sessions, que exige
// autenticación. Con un token bueno responde 200; con uno muerto
// responde 401 ("Token has invalid payload"). Es la comprobación más
// barata que existe: no hace falta ningún id de track.
//
// Verificado en vivo (2026-09):
//   GET api.tidal.com/v1/sessions  sin auth → 401 "Missing auth parameter"
//   GET api.tidal.com/v1/sessions  token malo → 401 "Token has invalid payload"
//
// Se conecta con: pool.go (núcleo genérico) y extensions_settings.go.
// Parte del flujo: sesiones de fuente (descarga directa con cuenta).
// ─────────────────────────────────────────────────────────────

package sessionpool

import (
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
)

// SessionsTidal es el endpoint que valida un access token.
const SessionsTidal = "https://api.tidal.com/v1/sessions"

// PublicTokenTidal es el token de cliente que Tidal usa en su propia
// web. Sin él, la API responde 400 "countryCode parameter missing" en
// vez de evaluar el token del usuario.
const PublicTokenTidal = "49YxDN9a2aFV6RTG"

// jwtRe reconoce un access token de Tidal (es un JWT).
var jwtRe = regexp.MustCompile(`eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}`)

// tokenLargoRe reconoce tokens opacos largos (algunas sesiones de Tidal
// no son JWT sino cadenas alfanuméricas largas).
var tokenLargoRe = regexp.MustCompile(`\b[A-Za-z0-9_-]{40,}\b`)

// ExtraerTokensTidal saca los access tokens candidatos de un texto.
func ExtraerTokensTidal(texto string) []string {
	return unicos(append(
		append(jwtRe.FindAllString(texto, -1), tokenLargoRe.FindAllString(texto, -1)...),
		ExtraerParesClaveValor(texto)...,
	))
}

// ValidarTokenTidal dice si el access token sigue sirviendo.
func ValidarTokenTidal(cliente *http.Client, token string) bool {
	return validarTokenTidalEn(cliente, SessionsTidal, token)
}

// validarTokenTidalEn es el validador con endpoint inyectable (tests).
func validarTokenTidalEn(cliente *http.Client, endpoint, token string) bool {
	token = strings.TrimSpace(token)
	if len(token) < 16 {
		return false
	}
	if cliente == nil {
		cliente = &http.Client{Timeout: timeoutValidacion}
	}

	// countryCode es obligatorio en la API de Tidal; da igual cuál sea
	// para saber si el token es válido.
	url := endpoint + "?countryCode=US"
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return false
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("x-tidal-token", PublicTokenTidal)

	resp, err := cliente.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	// Un token muerto da 401/403. Cualquier 2xx es sesión viva; Tidal
	// también responde 200 con el error embebido, así que hay que mirar
	// el cuerpo cuando el status es 200.
	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		return false
	}
	if resp.StatusCode >= 400 {
		return false
	}
	var payload struct {
		Status      json.Number `json:"status"`
		UserMessage string      `json:"userMessage"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		// 200 sin JSON reconocible: se acepta (algunas versiones
		// devuelven el objeto de sesión sin envoltorio).
		return true
	}
	status := strings.TrimSpace(payload.Status.String())
	return status == "" || status == "200"
}

// ConstruirPoolTidal arma el pool de access tokens de Tidal.
func ConstruirPoolTidal(cliente *http.Client, propias []string, fuentes []string, endpoint string) Resultado {
	if endpoint == "" {
		endpoint = SessionsTidal
	}
	return ConstruirPool(cliente, Opciones{
		Propias: sanearTokens(propias, 16),
		Fuentes: fuentes,
		Extraer: ExtraerTokensTidal,
		Validar: func(c *http.Client, token string) bool {
			return validarTokenTidalEn(c, endpoint, token)
		},
	})
}

// sanearTokens deja pasar solo lo que parece un token (largo mínimo y
// sin espacios), para que un texto pegado por error no entre al pool.
func sanearTokens(valores []string, minimo int) []string {
	salida := make([]string, 0, len(valores))
	for _, v := range valores {
		v = strings.TrimSpace(v)
		if len(v) >= minimo && !strings.ContainsAny(v, " \t") {
			salida = append(salida, v)
		}
	}
	return unicos(salida)
}
