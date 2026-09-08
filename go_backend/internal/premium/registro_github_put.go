package premium

// Registro de códigos en GitHub (parte 2: marcar como usado).
//
// Después de validar un código en el registro, se actualiza codes.json
// poniendo el código como "usado" para que no se pueda reutilizar. El
// flujo replica exactamente al PremiumService Dart: GET metadata (sha +
// content en base64) → decodificar → actualizar → PUT con el sha.

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

// marcarComoUsado actualiza codes.json en GitHub poniendo el código como
// "usado". Devuelve error si falla; el caller decide si es fatal (en Dart
// el fallo de este paso era no-fatal).
func marcarComoUsado(code, token string) error {
	if token == "" {
		return nil
	}
	// 1) GET metadata del archivo.
	req, err := http.NewRequest(http.MethodGet, codesAPIURL, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "token "+token)
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	resp, err := httpClientApp.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	var meta struct {
		SHA     string `json:"sha"`
		Content string `json:"content"`
	}
	if err := json.Unmarshal(body, &meta); err != nil {
		return err
	}

	// 2) Decodificar el contenido base64, actualizar el estado y re-codificar.
	raw, err := base64.StdEncoding.DecodeString(strings.ReplaceAll(meta.Content, "\n", ""))
	if err != nil {
		return err
	}
	var codes map[string]interface{}
	if err := json.Unmarshal(raw, &codes); err != nil {
		return err
	}
	codes[code] = "usado"
	updated, err := json.MarshalIndent(codes, "", "  ")
	if err != nil {
		return err
	}
	prefix := code
	if len(prefix) > 30 {
		prefix = prefix[:30]
	}

	// 3) PUT del archivo actualizado con el sha obtenido.
	payload := map[string]interface{}{
		"message": "premium: mark code as usado (" + prefix + "...)",
		"content": base64.StdEncoding.EncodeToString(updated),
		"sha":     meta.SHA,
	}
	bodyPut, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	reqPut, err := http.NewRequest(http.MethodPut, codesAPIURL, strings.NewReader(string(bodyPut)))
	if err != nil {
		return err
	}
	reqPut.Header.Set("Authorization", "token "+token)
	reqPut.Header.Set("Content-Type", "application/json")
	respPut, err := httpClientApp.Do(reqPut)
	if err != nil {
		return err
	}
	defer respPut.Body.Close()
	if respPut.StatusCode != http.StatusOK && respPut.StatusCode != http.StatusCreated {
		return fmt.Errorf("status %d", respPut.StatusCode)
	}
	return nil
}
