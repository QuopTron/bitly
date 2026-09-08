package premium

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"testing"
	"time"
)

// generarCodeApp replica el generador del lado emisor (el que usaba el
// PremiumService Dart para firmar): payload JSON {p, e} → base64url sin
// padding → firma HMAC-SHA256 del mensaje "dataB64.palabra" → base64url.
func generarCodeApp(t *testing.T, word string, expiresAt int64) string {
	t.Helper()
	payload, err := json.Marshal(map[string]interface{}{"p": word, "e": expiresAt})
	if err != nil {
		t.Fatal(err)
	}
	dataB64 := base64.RawURLEncoding.EncodeToString(payload)
	mac := hmac.New(sha256.New, []byte(appSecretKey))
	mac.Write([]byte(dataB64 + "." + word))
	sig := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	return dataB64 + "." + sig
}

func TestValidarEstructuraApp_Valido(t *testing.T) {
	code := generarCodeApp(t, "pablo", time.Now().Add(24*time.Hour).Unix())
	if err := validarEstructuraApp(code); err != nil {
		t.Fatalf("código válido rechazado: %v", err)
	}
}

func TestValidarEstructuraApp_Errores(t *testing.T) {
	futuro := time.Now().Add(24 * time.Hour).Unix()
	codigoFirma := generarCodeApp(t, "pablo", futuro)
	// Corromper la firma cambiando el último carácter por uno distinto seguro.
	ultimo := codigoFirma[len(codigoFirma)-1]
	cambio := byte('B')
	if ultimo == 'B' {
		cambio = 'A'
	}
	codigoFirma = codigoFirma[:len(codigoFirma)-1] + string(cambio)

	cases := []struct {
		name string
		code string
		want string
	}{
		{"vacío", "   ", "Código vacío"},
		{"formato", "sin-punto", "Formato inválido"},
		{"palabra no autorizada", generarCodeApp(t, "hacker", futuro), "Palabra no autorizada"},
		{"expirado", generarCodeApp(t, "pablo", time.Now().Add(-time.Hour).Unix()), "Código expirado"},
		{"firma inválida", codigoFirma, "Firma inválida"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := validarEstructuraApp(tc.code)
			if err == nil {
				t.Fatal("esperaba error, got nil")
			}
			if err.Error() != tc.want {
				t.Fatalf("got %q, want %q", err.Error(), tc.want)
			}
		})
	}
}

func TestValidateAppCode_ActivaPremiumSinToken(t *testing.T) {
	// Sin token de GitHub el registro se salta (igual que en Dart) y el código
	// válido activa premium local por 365 días.
	c := NewChecker(nil)
	code := generarCodeApp(t, "pablo", time.Now().Add(24*time.Hour).Unix())
	if err := c.ValidateAppCode(code); err != nil {
		t.Fatalf("ValidateAppCode: %v", err)
	}
	if !c.IsPremium() {
		t.Error("esperaba premium activado tras validar")
	}
	if err := c.CheckDownloadAllowed(); err != nil {
		t.Errorf("las descargas deberían estar permitidas: %v", err)
	}
}
