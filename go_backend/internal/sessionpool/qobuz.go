// ─────────────────────────────────────────────────────────────
// qobuz.go — Credenciales de Qobuz.
//
// Qobuz acepta dos formas y las dos entran al pool:
//   1. "email:password"  → la cuenta con la que se pide un token nuevo.
//   2. user_auth_token   → un token ya emitido.
//
// Cómo se validan (verificado en vivo, 2026-09):
//   1. POST user/login → 401 "Invalid username/email and password
//      combination" si no sirve; 200 + user_auth_token si sirve.
//   2. GET favorite/getUserFavorites → 401 "User authentication is
//      required." si el token está muerto; 200 si está vivo.
//
// Se conecta con: pool.go (núcleo genérico) y extensions_settings.go.
// Parte del flujo: sesiones de fuente (descarga directa con cuenta).
// ─────────────────────────────────────────────────────────────

package sessionpool

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/url"
	"regexp"
	"strings"
)

const (
	// LoginQobuz emite un user_auth_token a partir de la cuenta.
	LoginQobuz = "https://www.qobuz.com/api.json/0.2/user/login"
	// FavoritosQobuz valida un user_auth_token ya emitido (exige sesión).
	FavoritosQobuz = "https://www.qobuz.com/api.json/0.2/favorite/getUserFavorites"
	// AppIDLoginQobuz es el app_id con el que la extensión inicia sesión.
	AppIDLoginQobuz = "712109809"
	// AppIDPublicoQobuz es el app_id del widget (el único que hoy sirve
	// los métodos anónimos) y con el que se valida un token suelto.
	AppIDPublicoQobuz = "735532640"
)

// correoRe reconoce algo con forma de email dentro de una credencial.
var correoRe = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

// ExtraerCredencialesQobuz saca candidatos "email:password" y tokens
// sueltos de un texto cualquiera.
func ExtraerCredencialesQobuz(texto string) []string {
	salida := []string{}
	// 1) Pares email:password (uno por línea).
	for _, linea := range strings.Split(texto, "\n") {
		linea = strings.TrimSpace(strings.TrimLeft(strings.TrimSpace(linea), "-*|` "))
		linea = strings.Trim(linea, "|` ")
		if i := strings.Index(linea, ":"); i > 0 {
			correo := strings.TrimSpace(linea[:i])
			clave := strings.TrimSpace(linea[i+1:])
			if correoRe.MatchString(correo) && clave != "" {
				salida = append(salida, correo+":"+clave)
			}
		}
	}
	// 2) Tokens ya emitidos (pares clave=valor o cadenas largas).
	salida = append(salida, ExtraerParesClaveValor(texto)...)
	return unicos(salida)
}

// ValidarCredencialQobuz dice si la credencial sigue sirviendo, sea una
// cuenta (email:password) o un token ya emitido.
func ValidarCredencialQobuz(cliente *http.Client, credencial string) bool {
	return validarCredencialQobuzEn(cliente, LoginQobuz, FavoritosQobuz, credencial)
}

// validarCredencialQobuzEn es el validador con endpoints inyectables.
func validarCredencialQobuzEn(cliente *http.Client, loginURL, favoritosURL, credencial string) bool {
	credencial = strings.TrimSpace(credencial)
	if credencial == "" {
		return false
	}
	if cliente == nil {
		cliente = &http.Client{Timeout: timeoutValidacion}
	}

	// Caso 1: es una cuenta → se prueba el login.
	if i := strings.Index(credencial, ":"); i > 0 {
		correo := strings.TrimSpace(credencial[:i])
		clave := strings.TrimSpace(credencial[i+1:])
		if correoRe.MatchString(correo) && clave != "" {
			return loginQobuzEn(cliente, loginURL, correo, clave)
		}
	}

	// Caso 2: token ya emitido → se prueba un endpoint que exige sesión.
	endpoint := favoritosURL + "?app_id=" + url.QueryEscape(AppIDPublicoQobuz) +
		"&user_auth_token=" + url.QueryEscape(credencial) +
		"&type=tracks&limit=1"
	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return false
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("X-App-Id", AppIDPublicoQobuz)

	resp, err := cliente.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}

// loginQobuzEn intenta iniciar sesión y confirma que devolvió token.
func loginQobuzEn(cliente *http.Client, endpoint, correo, clave string) bool {
	url := endpoint + "?app_id=" + url.QueryEscape(AppIDLoginQobuz)
	cuerpo, err := json.Marshal(map[string]string{"email": correo, "password": clave})
	if err != nil {
		return false
	}
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(cuerpo))
	if err != nil {
		return false
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", userAgent)

	resp, err := cliente.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return false
	}
	var payload struct {
		UserAuthToken string `json:"user_auth_token"`
		User          struct {
			Credential struct {
				UserAuthToken string `json:"user_auth_token"`
			} `json:"credential"`
		} `json:"user"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return false
	}
	return strings.TrimSpace(payload.UserAuthToken) != "" ||
		strings.TrimSpace(payload.User.Credential.UserAuthToken) != ""
}

// ConstruirPoolQobuz arma el pool de credenciales de Qobuz.
func ConstruirPoolQobuz(cliente *http.Client, propias []string, fuentes []string, loginURL, favoritosURL string) Resultado {
	if loginURL == "" {
		loginURL = LoginQobuz
	}
	if favoritosURL == "" {
		favoritosURL = FavoritosQobuz
	}
	return ConstruirPool(cliente, Opciones{
		Propias: sanearCredencialesQobuz(propias),
		Fuentes: fuentes,
		Extraer: ExtraerCredencialesQobuz,
		Validar: func(c *http.Client, credencial string) bool {
			return validarCredencialQobuzEn(c, loginURL, favoritosURL, credencial)
		},
	})
}

// sanearCredencialesQobuz solo deja pasar cuentas bien formadas o
// tokens con pinta de token; así un texto pegado por error no entra.
func sanearCredencialesQobuz(valores []string) []string {
	salida := make([]string, 0, len(valores))
	for _, v := range valores {
		v = strings.TrimSpace(v)
		if i := strings.Index(v, ":"); i > 0 && correoRe.MatchString(strings.TrimSpace(v[:i])) {
			salida = append(salida, v)
			continue
		}
		if len(v) >= 16 && !strings.ContainsAny(v, " \t") {
			salida = append(salida, v)
		}
	}
	return unicos(salida)
}
