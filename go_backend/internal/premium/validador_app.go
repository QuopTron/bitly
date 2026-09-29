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
		return nuevoError("codigo_vacio", "Código vacío")
	}
	parts := strings.Split(code, ".")
	if len(parts) != 2 {
		return nuevoError("formato_invalido", "Formato inválido")
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
		return nuevoError("datos_ilegibles", "Error decodificando datos")
	}
	var payload struct {
		Palabra string `json:"p"`
		Expira  int64  `json:"e"`
	}
	if err := json.Unmarshal(raw, &payload); err != nil {
		return nuevoError("payload_ilegible", "Error parseando JSON")
	}
	word := strings.ToLower(payload.Palabra)
	if !appValidWords[word] {
		return nuevoError("palabra_no_autorizada", "Palabra no autorizada")
	}
	if time.Now().Unix() > payload.Expira {
		return nuevoError("codigo_expirado", "Código expirado")
	}
	expected := generarFirmaApp(dataB64 + "." + word)
	if sigB64 != expected {
		return nuevoError("firma_invalida", "Firma inválida")
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

// ValidateAppCode ejecuta el flujo completo de validación. Acepta DOS formatos:
//
//  1. FIRMADO (BITLY2.…): firma Ed25519 verificada con la CLAVE PÚBLICA que
//     lleva la app (ver firmados.go). Es el formato nuevo: nadie puede firmar
//     códigos nuevos sin la clave privada, y no hace falta ningún servidor.
//  2. LEGACY (dataB64.sigB64): la MISMA lógica de siempre — estructura con el
//     secreto HMAC + registro + marcar usado — para que los códigos que ya
//     repartiste sigan funcionando.
//
// En los dos casos pasa por el registro (si está configurado) para confirmar
// que el código existe y marcarlo como usado.
func (c *Checker) ValidateAppCode(code string) error {
	code = strings.TrimSpace(code)

	// El formato se decide ANTES de validar: si el código dice ser del formato
	// nuevo, un error suyo es definitivo (una firma rota tiene que decir
	// "firma inválida", no caer al validador legacy y confundir el motivo).
	if EsCodigoFirmado(code) {
		datos, err := ValidarFirmado(code)
		if err != nil {
			return err
		}
		if err := c.pasarPorRegistro(code); err != nil {
			return err
		}
		expira := datos.Expira
		if expira <= 0 {
			expira = time.Now().Add(365 * 24 * time.Hour).Unix()
		}
		c.activarPremium(code, datos.Tier, expira)
		return nil
	}

	if err := validarEstructuraApp(code); err != nil {
		return err
	}
	if err := c.pasarPorRegistro(code); err != nil {
		return err
	}
	c.activarPremium(code, "premium", time.Now().Add(365*24*time.Hour).Unix())
	return nil
}

// pasarPorRegistro confirma el código contra el registro (que existe y en qué
// estado está) y lo marca como usado.
//
// El token YA NO viaja dentro de la app: el trabajo lo hace tu Worker, que lo
// guarda en su propio entorno. Dos reglas que importan:
//
//	· si el registro NO responde, la activación NO se bloquea (la firma ya se
//	  validó local y el Worker puede no estar siempre activo): el "usado" queda
//	  anotado y se reintenta al arrancar;
//	· si el registro responde que el código está usado/cancelado, se bloquea
//	  (eso es lo que protege el reuso).
func (c *Checker) pasarPorRegistro(code string) error {
	if url := premiumRegistroURL(); url != "" {
		firmado := EsCodigoFirmado(code)
		estado, err := consultarRegistroWorker(url, code, "")
		if err != nil {
			encolarUsadoPendiente(code)
			return nil
		}
		if err := estadoAError(estado, firmado); err != nil {
			return err
		}
		if err := marcarUsadoWorker(url, code, firmado); err != nil {
			encolarUsadoPendiente(code)
		}
		return nil
	}

	// Camino directo: un token puesto a mano (builds de diagnóstico del dueño).
	// La app publicada no lleva ninguno, así que en la práctica no entra acá.
	token := c.githubTokenValue()
	if token == "" {
		return nil
	}
	if err := verificarEnRegistro(code, token); err != nil {
		return err
	}
	_ = marcarComoUsado(code, token)
	return nil
}

// activarPremium fija el estado premium.
func (c *Checker) activarPremium(code, tier string, expira int64) {
	if tier == "" {
		tier = "premium"
	}
	c.mu.Lock()
	c.status = Status{
		IsPremium: true,
		Code:      code,
		Tier:      tier,
		ExpiresAt: expira,
	}
	c.mu.Unlock()
}
