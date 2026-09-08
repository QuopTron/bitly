// que deben coincidir EXACTO con el contrato del PremiumService Dart
// (mayúscula inicial, acentos) — Flutter los muestra tal cual.
//
//lint:file-ignore ST1005 los mensajes de error son textos de UI en español
package premium

// Validador del formato legacy de la app (JWT "dataB64.sigB64").
//
// Esta lógica vivía hardcodeada en Flutter (lib/backend/services/
// premium_service.dart) con el secreto HMAC dentro del APK — cualquiera
// podía decompilar el binario y forjar códigos. Se portó a Go para sacar
// el secreto del lado Dart: el flujo completo (estructura + registro de
// GitHub + marcar como usado) corre acá y Flutter solo llama por RPC.
//
// El formato NO cambió: los códigos ya emitidos siguen validando porque
// el secreto, las palabras autorizadas y los mensajes de error son
// idénticos a los del PremiumService original.

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

// appSecretKey es la clave HMAC del formato legacy. Coincide exactamente con
// la constante "bitly_secret_key_v1" que usaba PremiumService en Dart.
const appSecretKey = "bitly_secret_key_v1"

// appValidWords son las palabras autorizadas dentro del payload del código.
var appValidWords = map[string]bool{"pablo": true, "pabol": true, "flox": true}

// validarEstructuraApp valida el formato del código: "dataB64.sigB64" con
// payload JSON {p: palabra, e: expiración} firmado con HMAC-SHA256.
// Devuelve nil si la estructura es válida, o el mismo mensaje de error en
// español que devolvía PremiumService en Dart (los callers de Flutter lo
// muestran tal cual).
func validarEstructuraApp(code string) error {
	code = strings.TrimSpace(code)
	if code == "" {
		return fmt.Errorf("Código vacío")
	}
	parts := strings.Split(code, ".")
	if len(parts) != 2 {
		return fmt.Errorf("Formato inválido")
	}
	dataB64, sigB64 := parts[0], parts[1]

	// Base64 URL-safe → estándar con padding (igual que en Dart).
	dataNorm := strings.NewReplacer("-", "+", "_", "/").Replace(dataB64)
	switch len(dataNorm) % 4 {
	case 2:
		dataNorm += "=="
	case 3:
		dataNorm += "="
	}
	raw, err := base64.StdEncoding.DecodeString(dataNorm)
	if err != nil {
		return fmt.Errorf("Error decodificando datos")
	}
	var payload struct {
		Palabra string `json:"p"`
		Expira  int64  `json:"e"`
	}
	if err := json.Unmarshal(raw, &payload); err != nil {
		return fmt.Errorf("Error parseando JSON")
	}
	word := strings.ToLower(payload.Palabra)
	if !appValidWords[word] {
		return fmt.Errorf("Palabra no autorizada")
	}
	if time.Now().Unix() > payload.Expira {
		return fmt.Errorf("Código expirado")
	}
	expected := generarFirmaApp(dataB64 + "." + word)
	if sigB64 != expected {
		return fmt.Errorf("Firma inválida")
	}
	return nil
}

// generarFirmaApp calcula HMAC-SHA256 del mensaje con el secreto legacy y lo
// codifica en base64 URL-safe sin padding (idéntico a base64Url + quitar '='
// del PremiumService Dart).
func generarFirmaApp(message string) string {
	mac := hmac.New(sha256.New, []byte(appSecretKey))
	mac.Write([]byte(message))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

// ValidateAppCode ejecuta el flujo completo de validación del formato legacy:
// estructura → registro de GitHub (si hay token) → marcar como usado. Si todo
// pasa, activa premium localmente por 365 días (igual que PremiumCache Dart).
func (c *Checker) ValidateAppCode(code string) error {
	if err := validarEstructuraApp(code); err != nil {
		return err
	}
	token := c.githubTokenValue()
	if token != "" {
		if err := verificarEnRegistro(code, token); err != nil {
			return err
		}
		// Marcar como usado es no-fatal (igual que en Dart).
		_ = marcarComoUsado(code, token)
	}
	c.mu.Lock()
	c.status = Status{
		IsPremium: true,
		Code:      code,
		Tier:      "premium",
		ExpiresAt: time.Now().Add(365 * 24 * time.Hour).Unix(),
	}
	c.mu.Unlock()
	return nil
}
