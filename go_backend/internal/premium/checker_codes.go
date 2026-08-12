package premium

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"time"
)

// CheckDownloadAllowed returns nil if download is allowed, error if blocked.
func (c *Checker) CheckDownloadAllowed() error {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if !c.status.IsPremium {
		return fmt.Errorf("las descargas requieren premium — ingresa un código válido en Configuración")
	}
	if c.status.ExpiresAt > 0 && time.Now().Unix() > c.status.ExpiresAt {
		return fmt.Errorf("suscripción premium expirada")
	}
	return nil
}

// GenerateCode creates a premium code with HMAC signature.
// Only used for admin/testing — real codes are pre-loaded.
func GenerateCode(payload string) string {
	mac := hmac.New(sha256.New, secretKey)
	mac.Write([]byte(payload))
	sig := hex.EncodeToString(mac.Sum(nil))[:6]
	return fmt.Sprintf("BITLY-%s-%s", payload, strings.ToUpper(sig))
}

func validateHMAC(payload, signature string) bool {
	mac := hmac.New(sha256.New, secretKey)
	mac.Write([]byte(payload))
	expected := hex.EncodeToString(mac.Sum(nil))[:6]
	return hmac.Equal([]byte(strings.ToUpper(expected)), []byte(strings.ToUpper(signature)))
}

func maskCode(code string) string {
	if len(code) <= 4 {
		return code
	}
	return code[:4] + strings.Repeat("*", len(code)-4)
}

// SetSecretKey overrides the default HMAC key for code validation.
func SetSecretKey(key string) {
	if key != "" {
		secretKey = []byte(key)
	}
}
