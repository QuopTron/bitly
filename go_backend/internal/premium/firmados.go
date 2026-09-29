// firmados.go — Códigos premium FIRMADOS (Ed25519).
//
// Por qué existe: los dos formatos viejos (validador_app.go y el "BITLY-…" de
// checker_codes.go) validan con un secreto HMAC que viaja DENTRO del binario.
// En un repo público eso es la llave pegada a la cerradura: el APK se abre con
// unzip + grep y con ese secreto cualquiera firma códigos válidos.
//
// La firma asimétrica lo da vuelta:
//
//	· el código se firma en TU máquina con la clave PRIVADA
//	  (scripts/keys/private_key.pem — nunca al repo);
//	· la app lleva SOLO la clave PÚBLICA, que verifica pero no puede firmar.
//
// Y no depende de ningún servidor: verificar una firma es matemática local, así
// que funciona sin internet y sin que nada esté "encendido".
//
// Formato (una sola línea, sin espacios):
//
//	BITLY2.<payload_base64url>.<firma_base64url>
//
// payload = JSON {"p":"<palabra>","t":"<tier>","e":<expEpoch>,"i":"<id>"}
//
// La firma es Ed25519 sobre los BYTES del payload (los mismos que viajan), así
// no hay forma de que el generador y la app no coincidan al volver a serializar.
// El generador es scripts/release/generar_codigo.py.
package premium

import (
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"strings"
	"time"
)

// PrefijoFirmado distingue el formato nuevo del legacy ("dataB64.sigB64") y del
// "BITLY-…". Se exporta para que las herramientas y las pruebas lo compartan.
const PrefijoFirmado = "BITLY2."

// clavePublicaFirmados es la clave PÚBLICA (32 bytes en base64) del par que vive
// en scripts/keys/. Es pública a propósito: viaja dentro de la app y no permite
// firmar nada. Para rotarla: generar_codigo.py / generar_claves.py.
const clavePublicaFirmados = "DPVABxXjluqWrBCKM9d7dh4dpPYDYq6h22s2m+9gJ6g="

// DatosFirmados es lo que declara un código firmado.
type DatosFirmados struct {
	Palabra string `json:"p"` // palabra autorizada (misma lista que el legacy)
	Tier    string `json:"t"` // "premium", "lifetime", …
	Expira  int64  `json:"e"` // epoch seconds
	ID      string `json:"i"` // identificador del código (para el registro)
}

// EsCodigoFirmado indica si el texto viene con el formato nuevo. Existe para
// decidir el camino SIN confundir errores: un código firmado con la firma
// rota tiene que decir "firma inválida", no caer al validador legacy.
func EsCodigoFirmado(code string) bool {
	return strings.HasPrefix(strings.ToUpper(strings.TrimSpace(code)), PrefijoFirmado)
}

// clavePublicaFirmadosBytes decodifica la clave embebida.
func clavePublicaFirmadosBytes() (ed25519.PublicKey, error) {
	raw, err := base64.StdEncoding.DecodeString(clavePublicaFirmados)
	if err != nil {
		return nil, nuevoError("clave_invalida", "configuración de firma inválida")
	}
	if len(raw) != ed25519.PublicKeySize {
		return nil, nuevoError("clave_invalida", "configuración de firma inválida")
	}
	return ed25519.PublicKey(raw), nil
}

// ValidarFirmado verifica un código del formato nuevo con la clave pública
// embebida. Devuelve los datos declarados (ya validados) o un ErrorPremium con
// el motivo que la UI ya sabe traducir.
func ValidarFirmado(code string) (*DatosFirmados, error) {
	clave, err := clavePublicaFirmadosBytes()
	if err != nil {
		return nil, err
	}
	return ValidarFirmadoCon(clave, code)
}

// ValidarFirmadoCon es la misma verificación con una clave dada. Existe para
// las pruebas: así el test arma su PROPIO par y no necesita un código real (un
// código de verdad metido en el repo sería un código que cualquiera puede usar).
func ValidarFirmadoCon(clave ed25519.PublicKey, code string) (*DatosFirmados, error) {
	code = strings.TrimSpace(code)
	if code == "" {
		return nil, nuevoError("codigo_vacio", "Código vacío")
	}
	if !EsCodigoFirmado(code) {
		return nil, nuevoError("formato_invalido", "Formato inválido")
	}

	partes := strings.Split(strings.TrimSpace(code), ".")
	if len(partes) != 3 || !strings.EqualFold(partes[0], "BITLY2") {
		return nil, nuevoError("formato_invalido", "Formato inválido")
	}

	payload, err := base64.RawURLEncoding.DecodeString(partes[1])
	if err != nil {
		return nil, nuevoError("datos_ilegibles", "Error decodificando datos")
	}
	firma, err := base64.RawURLEncoding.DecodeString(partes[2])
	if err != nil {
		return nil, nuevoError("datos_ilegibles", "Error decodificando datos")
	}

	// La firma va PRIMERO: si no es de tu clave privada, no se mira ni el
	// contenido (así un payload inventado no llega nunca al parseo).
	if len(clave) != ed25519.PublicKeySize || !ed25519.Verify(clave, payload, firma) {
		return nil, nuevoError("firma_invalida", "Firma inválida")
	}

	var datos DatosFirmados
	if err := json.Unmarshal(payload, &datos); err != nil {
		return nil, nuevoError("payload_ilegible", "Error parseando JSON")
	}

	if !appValidWords[strings.ToLower(datos.Palabra)] {
		return nil, nuevoError("palabra_no_autorizada", "Palabra no autorizada")
	}
	if datos.Expira > 0 && time.Now().Unix() > datos.Expira {
		return nil, nuevoError("codigo_expirado", "Código expirado")
	}
	if datos.Tier == "" {
		datos.Tier = "premium"
	}
	return &datos, nil
}
