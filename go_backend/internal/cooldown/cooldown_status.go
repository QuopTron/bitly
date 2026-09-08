package cooldown

import (
	"strings"
	"time"
)

// ProviderStatus guarda la info de cooldown de un solo provider.
type ProviderStatus struct {
	Name    string `json:"name"`
	Cooled  bool   `json:"cooled"`
	Seconds int    `json:"seconds"` // segundos restantes de cooldown
}

// GetAllStatus devuelve el estado de cooldown de todos los providers enfriados.
func GetAllStatus() []ProviderStatus {
	mutex.Lock()
	defer mutex.Unlock()
	ahora := time.Now()
	var resultado []ProviderStatus
	for clave, hasta := range enfriados {
		if ahora.Before(hasta) {
			segs := int(time.Until(hasta).Seconds()) + 1
			resultado = append(resultado, ProviderStatus{Name: clave, Cooled: true, Seconds: segs})
		} else {
			delete(enfriados, clave)
		}
	}
	return resultado
}

// requiereVerificacion reporta si [errMsg] indica que el provider necesita
// completar su sesión firmada / challenge Cloudflare antes de servir.
func requiereVerificacion(errMsg string) bool {
	if errMsg == "" {
		return false
	}
	e := strings.ToLower(errMsg)
	for _, marcador := range []string{
		"verify_required",
		"verify required",
		"verification required",
		"precondition required",
		"http 428",
		"status 428",
	} {
		if strings.Contains(e, marcador) {
			return true
		}
	}
	return false
}

// limitadoObloqueado reporta si [errMsg] coincide con una condición que justifica enfriar el provider.
func limitadoObloqueado(errMsg string) bool {
	if errMsg == "" {
		return false
	}
	e := strings.ToLower(errMsg)
	for _, marcador := range []string{
		"429",
		"too many requests",
		"rate limit",
		"temporarily unavailable",
		"client decryption",
		"encriptado",
		// Respuestas con acceso restringido (sesiones web anónimas bloqueadas /
		// APIs sin sesión): qobuz-web devuelve 403 hasta firmar, amazon devuelve
		// página de login, tidal/bot checks 403. Tratarlos como rate-limit
		// detiene el walk por-track contra una fuente que hoy no puede servir.
		"403",
		"forbidden",
		"blocked",
		"bot detection",
		"captcha",
		// Errores de gateway/origen: varias fuentes resuelven vía un gateway
		// compartido (api.zarz.moe). Cuando ese origen cae, Cloudflare responde
		// 522/524/502/503/504 — reintentar en el siguiente track es inútil.
		"http 5",
		"522",
		"524",
		"gateway",
		// YouTube bloqueó esta IP/cuenta en todos los clientes InnerTube: el
		// resolver reporta "all clients failed" — enfriar el provider en vez de
		// re-walkear toda su cadena de clientes por track.
		"all clients failed",
		// VERIFY_REQUIRED de un provider de sesión firmada (tidal/qobuz/amazon/
		// deezer): la fuente no puede servir hasta que un humano complete el
		// challenge. Enfriarlo (ventana corta) detiene el martilleo por track.
		"verify_required",
		"verify required",
		"verification required",
		"precondition required",
		"http 428",
		"status 428",
	} {
		if strings.Contains(e, marcador) {
			return true
		}
	}
	return false
}
