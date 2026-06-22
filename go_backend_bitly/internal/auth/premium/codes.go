package premium

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
)

// GenerateCode creates a new premium code for the given word and expiration.
func GenerateCode(word string, expiresAt int64) (string, error) {
	word = strings.TrimSpace(word)
	if word == "" {
		return "", fmt.Errorf("word is required")
	}

	data := CodeData{
		Word:      word,
		ExpiresAt: expiresAt,
	}
	dataJSON, err := json.Marshal(data)
	if err != nil {
		return "", fmt.Errorf("failed to marshal code data: %w", err)
	}

	dataB64 := base64.StdEncoding.EncodeToString(dataJSON)
	dataB64 = strings.NewReplacer("+", "-", "/", "_").Replace(dataB64)
	dataB64 = strings.TrimRight(dataB64, "=")

	message := dataB64 + "." + word
	h := hmac.New(sha256.New, []byte(secretKey))
	h.Write([]byte(message))
	sum := h.Sum(nil)

	sig := base64.StdEncoding.EncodeToString(sum)
	sig = strings.NewReplacer("+", "-", "/", "_").Replace(sig)
	sig = strings.TrimRight(sig, "=")

	return dataB64 + "." + sig, nil
}

// ParseCode decodes a premium code string without full validation.
func ParseCode(code string) (*PremiumCode, error) {
	code = strings.TrimSpace(code)
	parts := strings.Split(code, ".")
	if len(parts) != 2 {
		return nil, fmt.Errorf("invalid code format")
	}

	return &PremiumCode{
		Signature: parts[1],
	}, nil
}
