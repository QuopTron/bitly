package extensions

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"strings"
	"time"
)

func sanitizarNamespaceSesionFirmada(namespace string) string {
	namespace = strings.ToLower(strings.TrimSpace(namespace))
	var b strings.Builder
	for _, ch := range namespace {
		if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '-' || ch == '_' || ch == '.' {
			b.WriteRune(ch)
		}
	}
	return strings.Trim(b.String(), ".-_")
}

func hexAleatorio(bytesLen int) string {
	buf := make([]byte, bytesLen)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(buf)
}

func parsearTiempoSesionFirmada(value string) (time.Time, bool) {
	value = strings.TrimSpace(value)
	if value == "" {
		return time.Time{}, false
	}
	layouts := []string{time.RFC3339Nano, time.RFC3339, "2006-01-02T15:04:05.000Z"}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed, true
		}
	}
	return time.Time{}, false
}

// signedSessionRecordIsUsable indica si un registro de sesion firmada sigue
// siendo valido (tiene credenciales y no esta expirado).
func signedSessionRecordIsUsable(record *signedSessionRecord) bool {
	if record == nil || strings.TrimSpace(record.SessionID) == "" ||
		strings.TrimSpace(record.SessionSecret) == "" {
		return false
	}
	if expiresAt, ok := parsearTiempoSesionFirmada(record.ExpiresAt); ok {
		return time.Now().Before(expiresAt)
	}
	return true
}
