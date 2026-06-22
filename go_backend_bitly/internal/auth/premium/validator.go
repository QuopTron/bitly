package premium

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

// ValidWords is the whitelist of allowed code words.
var ValidWords = map[string]bool{
	"pablo": true,
	"pabol": true,
	"flox":  true,
}

// PremiumCode represents a decoded premium code.
type PremiumCode struct {
	Data      CodeData `json:"d"`
	Signature string   `json:"s"`
}

// CodeData contains the payload of a premium code.
type CodeData struct {
	Word      string `json:"p"`
	ExpiresAt int64  `json:"e"` // Unix timestamp (seconds)
}

// PremiumStatus is the result of validating a code.
type PremiumStatus struct {
	IsPremium bool   `json:"is_premium"`
	ExpiresAt int64  `json:"expires_at,omitempty"`
	Error     string `json:"error,omitempty"`
}

// ValidateCode validates a premium code string.
func ValidateCode(code string) (*PremiumStatus, error) {
	code = strings.TrimSpace(code)
	if code == "" {
		return &PremiumStatus{Error: "Código vacío"}, fmt.Errorf("empty code")
	}

	parts := strings.Split(code, ".")
	if len(parts) != 2 {
		return &PremiumStatus{Error: "Formato inválido"}, fmt.Errorf("invalid format")
	}

	dataB64 := parts[0]
	sigB64 := parts[1]

	// Normalize Base64 URL-safe to standard
	dataB64Norm := strings.NewReplacer("-", "+", "_", "/").Replace(dataB64)
	switch len(dataB64Norm) % 4 {
	case 2:
		dataB64Norm += "=="
	case 3:
		dataB64Norm += "="
	}

	dataJSON, err := base64.StdEncoding.DecodeString(dataB64Norm)
	if err != nil {
		return &PremiumStatus{Error: "Error decodificando datos"}, fmt.Errorf("decode error: %w", err)
	}

	var codeData CodeData
	if err := json.Unmarshal(dataJSON, &codeData); err != nil {
		return &PremiumStatus{Error: "Error parseando JSON"}, fmt.Errorf("json error: %w", err)
	}

	// Validate word
	word := strings.ToLower(codeData.Word)
	if !ValidWords[word] {
		return &PremiumStatus{Error: "Palabra no autorizada"}, fmt.Errorf("unauthorized word")
	}

	// Validate expiration
	now := time.Now().Unix()
	if now > codeData.ExpiresAt {
		return &PremiumStatus{Error: "Código expirado"}, fmt.Errorf("code expired")
	}

	// Validate signature
	message := dataB64 + "." + word
	expectedSig := generateSignature(message)
	if sigB64 != expectedSig {
		return &PremiumStatus{Error: "Firma inválida"}, fmt.Errorf("invalid signature")
	}

	return &PremiumStatus{
		IsPremium: true,
		ExpiresAt: codeData.ExpiresAt,
	}, nil
}

func generateSignature(message string) string {
	h := hmac.New(sha256.New, []byte(secretKey))
	h.Write([]byte(message))
	sum := h.Sum(nil)

	result := base64.StdEncoding.EncodeToString(sum)
	result = strings.NewReplacer("+", "-", "/", "_").Replace(result)
	result = strings.TrimRight(result, "=")
	return result
}
