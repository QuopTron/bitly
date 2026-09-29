package premium

import (
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"os"
	"strings"
	"testing"
	"time"
)

// payloadFirmado es el cuerpo que se firma (los mismos nombres que documenta
// firmados.go). En la prueba se arma con json.Marshal: la firma es sobre los
// BYTES, así que el orden lo fija quien firma y no importa acá.
type payloadFirmado struct {
	Palabra string `json:"p"`
	Tier    string `json:"t"`
	Expira  int64  `json:"e"`
	ID      string `json:"i"`
}

// armarCodigoFirmado firma un payload con la clave dada y devuelve el código
// con el formato real (BITLY2.<payload>.<firma> en base64url sin padding).
func armarCodigoFirmado(t *testing.T, k ed25519.PrivateKey, p payloadFirmado) string {
	t.Helper()
	crudo, err := json.Marshal(p)
	if err != nil {
		t.Fatalf("marshal del payload: %v", err)
	}
	firma := ed25519.Sign(k, crudo)
	return PrefijoFirmado +
		base64.RawURLEncoding.EncodeToString(crudo) + "." +
		base64.RawURLEncoding.EncodeToString(firma)
}

// parDePrueba arma un par NUEVO por prueba: así el repo no guarda ningún código
// real (un código de verdad en un repo público lo puede usar cualquiera).
func parDePrueba(t *testing.T) (ed25519.PublicKey, ed25519.PrivateKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("generando el par: %v", err)
	}
	return pub, priv
}

// codigoLegacyDePrueba arma un código del formato viejo (dataB64.sigB64) con la
// firma real del paquete: sirve para comprobar que ese camino NO se tocó.
func codigoLegacyDePrueba(t *testing.T, palabra string, expira time.Time) string {
	t.Helper()
	crudo, err := json.Marshal(struct {
		P string `json:"p"`
		E int64  `json:"e"`
	}{P: palabra, E: expira.Unix()})
	if err != nil {
		t.Fatalf("marshal legacy: %v", err)
	}
	dataB64 := base64.RawURLEncoding.EncodeToString(crudo)
	return dataB64 + "." + generarFirmaApp(dataB64+"."+strings.ToLower(palabra))
}

func TestFirmadoValido(t *testing.T) {
	pub, priv := parDePrueba(t)
	code := armarCodigoFirmado(t, priv, payloadFirmado{
		Palabra: "pablo",
		Tier:    "premium",
		Expira:  time.Now().Add(365 * 24 * time.Hour).Unix(),
		ID:      "prueba-1",
	})

	if !EsCodigoFirmado(code) {
		t.Fatal("EsCodigoFirmado no reconoció el código nuevo")
	}
	datos, err := ValidarFirmadoCon(pub, code)
	if err != nil {
		t.Fatalf("código válido rechazado: %v", err)
	}
	if datos.Tier != "premium" || datos.ID != "prueba-1" {
		t.Fatalf("datos mal leídos: %+v", datos)
	}
}

func TestFirmadoSinTierQuedaPremium(t *testing.T) {
	pub, priv := parDePrueba(t)
	code := armarCodigoFirmado(t, priv, payloadFirmado{
		Palabra: "flox",
		Expira:  time.Now().Add(24 * time.Hour).Unix(),
	})
	datos, err := ValidarFirmadoCon(pub, code)
	if err != nil {
		t.Fatalf("código válido rechazado: %v", err)
	}
	if datos.Tier != "premium" {
		t.Fatalf("sin tier debería quedar premium, quedó %q", datos.Tier)
	}
}

func TestFirmadoDeOtraClaveSeRechaza(t *testing.T) {
	_, privAjeno := parDePrueba(t)
	pub, _ := parDePrueba(t)

	code := armarCodigoFirmado(t, privAjeno, payloadFirmado{
		Palabra: "pablo",
		Expira:  time.Now().Add(time.Hour).Unix(),
	})
	if _, err := ValidarFirmadoCon(pub, code); MotivoDeError(err) != "firma_invalida" {
		t.Fatalf("firma de otro par: motivo %q (error: %v)", MotivoDeError(err), err)
	}
}

func TestFirmadoConPayloadTocadoSeRechaza(t *testing.T) {
	pub, priv := parDePrueba(t)
	code := armarCodigoFirmado(t, priv, payloadFirmado{
		Palabra: "pablo",
		Expira:  time.Now().Add(time.Hour).Unix(),
	})

	// Se estira la expiración del payload y se deja la firma vieja: es el
	// intento de revivir un código vencido.
	partes := strings.Split(code, ".")
	crudo, err := base64.RawURLEncoding.DecodeString(partes[1])
	if err != nil {
		t.Fatalf("decodificando el payload: %v", err)
	}
	var datos map[string]any
	if err := json.Unmarshal(crudo, &datos); err != nil {
		t.Fatalf("parseando el payload: %v", err)
	}
	datos["e"] = time.Now().Add(100 * 365 * 24 * time.Hour).Unix()
	nuevo, _ := json.Marshal(datos)
	tocado := partes[0] + "." + base64.RawURLEncoding.EncodeToString(nuevo) + "." + partes[2]

	if _, err := ValidarFirmadoCon(pub, tocado); MotivoDeError(err) != "firma_invalida" {
		t.Fatalf("payload modificado: motivo %q (error: %v)", MotivoDeError(err), err)
	}
}

func TestFirmadoVencidoSeRechaza(t *testing.T) {
	pub, priv := parDePrueba(t)
	code := armarCodigoFirmado(t, priv, payloadFirmado{
		Palabra: "pablo",
		Expira:  time.Now().Add(-time.Hour).Unix(),
	})
	if _, err := ValidarFirmadoCon(pub, code); MotivoDeError(err) != "codigo_expirado" {
		t.Fatalf("código vencido: motivo %q (error: %v)", MotivoDeError(err), err)
	}
}

func TestFirmadoPalabraNoAutorizada(t *testing.T) {
	pub, priv := parDePrueba(t)
	code := armarCodigoFirmado(t, priv, payloadFirmado{
		Palabra: "otra",
		Expira:  time.Now().Add(time.Hour).Unix(),
	})
	if _, err := ValidarFirmadoCon(pub, code); MotivoDeError(err) != "palabra_no_autorizada" {
		t.Fatalf("palabra no autorizada: motivo %q (error: %v)", MotivoDeError(err), err)
	}
}

func TestFirmadoFormatoRoto(t *testing.T) {
	pub, _ := parDePrueba(t)
	payloadRoto := base64.RawURLEncoding.EncodeToString([]byte(`{"p":"pablo","e":1}`))
	casos := map[string]string{
		"sin partes":     PrefijoFirmado + "solopayload",
		"payload basura": PrefijoFirmado + "!!!.!!!",
		"firma basura":   PrefijoFirmado + payloadRoto + ".!!!",
		"cuatro partes":  PrefijoFirmado + "a.b.c",
		"vacío":          "",
	}
	for nombre, code := range casos {
		_, err := ValidarFirmadoCon(pub, code)
		if err == nil {
			t.Fatalf("%s: debería fallar y no falló", nombre)
		}
		if MotivoDeError(err) == "" {
			t.Fatalf("%s: error sin motivo traducible (%v)", nombre, err)
		}
	}
}

// La clave pública embebida tiene que estar bien formada y ser la misma que la
// de scripts/keys/: si alguien la pega mal, NINGÚN código nuevo validaría y el
// fallo tiene que aparecer acá y no en producción.
func TestClavePublicaEmbebidaEsValida(t *testing.T) {
	clave, err := clavePublicaFirmadosBytes()
	if err != nil {
		t.Fatalf("la clave pública embebida no es válida: %v", err)
	}
	if len(clave) != ed25519.PublicKeySize {
		t.Fatalf("la clave mide %d bytes (esperado %d)", len(clave), ed25519.PublicKeySize)
	}

	// Comprobación cruzada con el archivo del repo. La carpeta scripts/keys/ está
	// en .gitignore (no viaja al repo), así que en CI se saltea.
	ruta := "../../../scripts/keys/public_key.pem"
	crudo, err := os.ReadFile(ruta)
	if err != nil {
		t.Skipf("no encontré %s (%v): se saltea la comprobación cruzada", ruta, err)
	}
	var cuerpo strings.Builder
	for _, l := range strings.Split(string(crudo), "\n") {
		l = strings.TrimSpace(strings.TrimSuffix(l, "\r"))
		if l == "" || strings.HasPrefix(l, "-----") {
			continue
		}
		cuerpo.WriteString(l)
	}
	if cuerpo.String() != clavePublicaFirmados {
		t.Fatal("la clave pública embebida NO es la de scripts/keys/public_key.pem: los códigos generados con ese par no van a validar")
	}
}

// El camino legacy NO se toca: un código viejo sigue activando premium igual
// que siempre (sin token configurado no hay registro, como antes).
func TestLegacySigueFuncionando(t *testing.T) {
	c := NewChecker(nil)
	code := codigoLegacyDePrueba(t, "pablo", time.Now().Add(24*time.Hour))

	if err := c.ValidateAppCode(code); err != nil {
		t.Fatalf("código legacy rechazado: %v", err)
	}
	if !c.IsPremium() {
		t.Fatal("el código legacy no activó premium")
	}
	if c.Status().Tier != "premium" {
		t.Fatalf("tier del legacy: %q", c.Status().Tier)
	}
}

// Un código con el formato NUEVO y la firma rota tiene que decir "firma
// inválida" (y no caer al validador legacy, que diría "formato inválido").
func TestFirmadoRotoNoCaeAlLegacy(t *testing.T) {
	c := NewChecker(nil)
	_, privAjeno := parDePrueba(t)
	code := armarCodigoFirmado(t, privAjeno, payloadFirmado{
		Palabra: "pablo",
		Expira:  time.Now().Add(time.Hour).Unix(),
	})
	if err := c.ValidateAppCode(code); MotivoDeError(err) != "firma_invalida" {
		t.Fatalf("motivo %q (error: %v)", MotivoDeError(err), err)
	}
	if c.IsPremium() {
		t.Fatal("no debería haber activado premium")
	}
}

// Y un código firmado de verdad (con el par de scripts/keys/) tiene que activar
// premium de punta a punta, con su expiración declarada. Se saltea si no está la
// clave privada (CI).
func TestFirmadoActivaPremiumDePuntaAPunta(t *testing.T) {
	privCruda, err := os.ReadFile("../../../scripts/keys/private_key.pem")
	if err != nil {
		t.Skipf("no encontré la clave privada (%v): se saltea", err)
	}
	var cuerpo strings.Builder
	for _, l := range strings.Split(string(privCruda), "\n") {
		l = strings.TrimSpace(strings.TrimSuffix(l, "\r"))
		if l == "" || strings.HasPrefix(l, "-----") {
			continue
		}
		cuerpo.WriteString(l)
	}
	semilla, err := base64.StdEncoding.DecodeString(cuerpo.String())
	if err != nil || len(semilla) != ed25519.SeedSize {
		t.Fatalf("la clave privada del repo no es una semilla Ed25519 válida (err=%v, %d bytes)", err, len(semilla))
	}

	expira := time.Now().Add(48 * time.Hour).Unix()
	code := armarCodigoFirmado(t, ed25519.NewKeyFromSeed(semilla), payloadFirmado{
		Palabra: "pablo",
		Tier:    "lifetime",
		Expira:  expira,
		ID:      "prueba-punta-a-punta",
	})

	c := NewChecker(nil)
	if err := c.ValidateAppCode(code); err != nil {
		t.Fatalf("el código firmado no activó premium: %v", err)
	}
	estado := c.Status()
	if !estado.IsPremium || estado.Tier != "lifetime" {
		t.Fatalf("estado inesperado: %+v", estado)
	}
	if estado.ExpiresAt != expira {
		t.Fatalf("expiración: %d (esperado %d)", estado.ExpiresAt, expira)
	}
}
