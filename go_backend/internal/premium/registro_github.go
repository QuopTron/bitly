// que deben coincidir EXACTO con el contrato del PremiumService Dart.
//
//lint:file-ignore ST1005 los mensajes de error son textos de UI en español
package premium

// Registro de códigos en GitHub (parte 1: consulta).
//
// El repositorio QuopTron/bitly_codes_premium guarda codes.json con el
// estado de cada código (activo / usado / cancelado / libre). Antes esta
// consulta la hacía PremiumService en Dart con el token personal de GitHub;
// ahora vive acá y Flutter solo manda el token por RPC (SetGithubToken).

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// codesAPIURL es el repositorio de GitHub que guarda el registro de códigos.
const codesAPIURL = "https://api.github.com/repos/QuopTron/bitly_codes_premium/contents/codes.json"

// httpClientApp es el cliente HTTP para las llamadas a la API de GitHub
// (mismo timeout de 10s que usaba el PremiumService Dart).
var httpClientApp = &http.Client{Timeout: 10 * time.Second}

// verificarEnRegistro consulta codes.json en GitHub y valida el estado del
// código. Sin token no se puede verificar el registro.
func verificarEnRegistro(code, token string) error {
	if token == "" {
		return fmt.Errorf("No se pudo verificar el código en el registro")
	}
	codes, err := fetchCodesJSON(token)
	if err != nil {
		return fmt.Errorf("No se pudo verificar el código en el registro")
	}
	status, ok := codes[code]
	if !ok {
		return fmt.Errorf("Código no encontrado en el registro")
	}
	switch status {
	case "activo":
		return nil
	case "usado":
		return fmt.Errorf("Código ya usado")
	case "cancelado":
		return fmt.Errorf("Código cancelado")
	case "libre":
		return fmt.Errorf("Código liberado")
	default:
		return fmt.Errorf("Estado desconocido: %s", status)
	}
}

// fetchCodesJSON descarga el contenido crudo de codes.json con el token de
// GitHub (Accept: raw), quita la clave "_NOTA" y devuelve el mapa
// código → estado.
func fetchCodesJSON(token string) (map[string]string, error) {
	req, err := http.NewRequest(http.MethodGet, codesAPIURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "token "+token)
	req.Header.Set("Accept", "application/vnd.github.v3.raw")
	resp, err := httpClientApp.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	var decoded map[string]interface{}
	if err := json.Unmarshal(body, &decoded); err != nil {
		return nil, err
	}
	delete(decoded, "_NOTA")
	out := make(map[string]string, len(decoded))
	for k, v := range decoded {
		out[k] = fmt.Sprintf("%v", v)
	}
	return out, nil
}
