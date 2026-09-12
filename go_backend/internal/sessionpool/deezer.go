// ─────────────────────────────────────────────────────────────
// deezer.go — Credenciales de Deezer: ARL (cookie de sesión).
//
// Un ARL se valida igual que en la extensión: una llamada a
// deezer.getUserData en el gateway ligero. Solo una sesión viva
// devuelve un USER_ID distinto de 0. Así el pool nunca entrega una
// credencial muerta: se la descarta antes de que el usuario la sufra.
//
// Se conecta con: pool.go (núcleo genérico) y extensions_settings.go.
// Parte del flujo: sesiones de fuente (descarga directa con cuenta).
// ─────────────────────────────────────────────────────────────

package sessionpool

import (
	"bytes"
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
	"time"
)

// GatewayDeezer es el endpoint que usa la propia web de Deezer para su
// API interna. Es el mismo que llama la extensión deezer.
const GatewayDeezer = "https://www.deezer.com/ajax/gw-light.php"

// timeoutValidacion por credencial: validar 10 credenciales no puede
// tardar más que unos segundos.
const timeoutValidacion = 8 * time.Second

// arlRe reconoce un ARL de Deezer (32 hex). Se acepta tanto suelto como
// dentro de HTML, markdown o JSON.
var arlRe = regexp.MustCompile(`\b[0-9a-fA-F]{32}\b`)

// ExtraerARLs saca todos los ARLs candidatos de un texto cualquiera.
func ExtraerARLs(texto string) []string {
	return unicos(append(
		arlRe.FindAllString(texto, -1),
		ExtraerParesClaveValor(texto)...,
	))
}

// ValidarARLDeezer dice si el ARL sigue sirviendo contra el gateway real.
func ValidarARLDeezer(cliente *http.Client, arl string) bool {
	return validarARLEn(cliente, GatewayDeezer, arl)
}

// validarARLEn es el validador con endpoint inyectable (tests).
func validarARLEn(cliente *http.Client, endpoint, arl string) bool {
	arl = strings.TrimSpace(arl)
	if len(arl) < 16 {
		return false
	}
	if cliente == nil {
		cliente = &http.Client{Timeout: timeoutValidacion}
	}

	url := endpoint + "?method=deezer.getUserData&input=3&api_version=1.0&api_token="
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader([]byte("{}")))
	if err != nil {
		return false
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Cookie", "arl="+arl)

	resp, err := cliente.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return false
	}

	// El gateway envuelve el resultado: {"results":{"USER":{"USER_ID":...}}}
	var payload struct {
		Results struct {
			USER struct {
				UserID json.Number `json:"USER_ID"`
			} `json:"USER"`
		} `json:"results"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return false
	}
	id := strings.TrimSpace(payload.Results.USER.UserID.String())
	// USER_ID 0 es la forma que usa Deezer para decir "credencial muerta".
	return id != "" && id != "0"
}

// ConstruirPoolARP arma el pool de ARLs de Deezer.
//
// endpoint es configurable (vacío = gateway real) para poder probarlo
// contra un servidor local.
func ConstruirPoolARP(cliente *http.Client, propias []string, fuentes []string, endpoint string) Resultado {
	if endpoint == "" {
		endpoint = GatewayDeezer
	}
	return ConstruirPool(cliente, Opciones{
		Propias: sanearARLs(propias),
		Fuentes: fuentes,
		Extraer: ExtraerARLs,
		Validar: func(c *http.Client, arl string) bool {
			return validarARLEn(c, endpoint, arl)
		},
	})
}

// sanearARLs deja pasar solo lo que tiene forma de ARL (32 hex), para
// que un texto pegado por error no entre al pool como credencial.
func sanearARLs(valores []string) []string {
	salida := make([]string, 0, len(valores))
	for _, v := range valores {
		v = strings.TrimSpace(v)
		if arlRe.MatchString(v) {
			salida = append(salida, v)
		}
	}
	return unicos(salida)
}
