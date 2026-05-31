package gobackend

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

const secretKey = "bitly_secret_key_v1"

var palabrasValidas = map[string]bool{
	"pablo": true,
	"pabol": true,
	"flox":  true,
}

type ValidarCodigoResult struct {
	Valido   bool
	Expiry   int64
	ErrorMsg string
}

func ValidarCodigoPremium(codigo string) ValidarCodigoResult {
	codigo = strings.TrimSpace(codigo)
	if codigo == "" {
		return ValidarCodigoResult{false, 0, "Código vacío"}
	}

	partes := strings.Split(codigo, ".")
	if len(partes) != 2 {
		return ValidarCodigoResult{false, 0, "Formato inválido"}
	}

	datosB64 := partes[0]
	firmaB64 := partes[1]

	// Normalizar base64 URL-safe a estándar
	datosB64Norm := strings.ReplaceAll(datosB64, "-", "+")
	datosB64Norm = strings.ReplaceAll(datosB64Norm, "_", "/")

	// Agregar padding si es necesario
	switch len(datosB64Norm) % 4 {
	case 2:
		datosB64Norm += "=="
	case 3:
		datosB64Norm += "="
	}

	datosJSON, err := base64.StdEncoding.DecodeString(datosB64Norm)
	if err != nil {
		return ValidarCodigoResult{false, 0, "Error decodificando datos: " + err.Error()}
	}

	var datos map[string]interface{}
	if err := json.Unmarshal(datosJSON, &datos); err != nil {
		return ValidarCodigoResult{false, 0, "Error parseando JSON"}
	}

	palabra, ok := datos["p"].(string)
	if !ok {
		return ValidarCodigoResult{false, 0, "Palabra no encontrada"}
	}

	palabra = strings.ToLower(palabra)
	if !palabrasValidas[palabra] {
		return ValidarCodigoResult{false, 0, "Palabra no autorizada"}
	}

	expiryFloat, ok := datos["e"].(float64)
	if !ok {
		return ValidarCodigoResult{false, 0, "Expiración no encontrada"}
	}
	expiry := int64(expiryFloat)

	now := time.Now().Unix()
	if now > expiry {
		return ValidarCodigoResult{false, 0, "Código expirado"}
	}

	mensaje := datosB64 + "." + palabra
	expectedFirma := generarFirma(mensaje)

	if firmaB64 != expectedFirma {
		return ValidarCodigoResult{false, 0, "Firma inválida"}
	}

	return ValidarCodigoResult{true, expiry, ""}
}

func generarFirma(mensaje string) string {
	h := hmac.New(sha256.New, []byte(secretKey))
	h.Write([]byte(mensaje))
	sum := h.Sum(nil)

	result := base64.StdEncoding.EncodeToString(sum)
	result = strings.ReplaceAll(result, "+", "-")
	result = strings.ReplaceAll(result, "/", "_")
	result = strings.TrimRight(result, "=")
	return result
}

type PremiumInfo struct {
	Activo    bool  `json:"activo"`
	ExpiraEn  int64 `json:"expira_en"`
	Timestamp int64 `json:"timestamp"`
}

func VerificarPremium(isPremium bool, premiumUntil int64) error {
	if isPremium && premiumUntil == 0 {
		return nil
	}

	if premiumUntil > 0 {
		now := time.Now().UnixMilli()
		if now > premiumUntil {
			return fmt.Errorf("Período de prueba vencido")
		}
		return nil
	}

	return fmt.Errorf("Premium requerido")
}
