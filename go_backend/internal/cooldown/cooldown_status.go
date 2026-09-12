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
		// 401 Unauthorized tampoco estaba contemplado, y es el que más costaba:
		// SoundCloud responde 401 en TODAS sus llamadas cuando no logra resolver
		// su client_id (su scrape cambia con cada variante de frontend que sirve).
		// Sin este marcador cada canción del lote volvía a caminar la fuente con
		// ~8 peticiones condenadas — segundos perdidos por track en cada
		// fallback, justo cuando el usuario espera que suene la siguiente.
		// Se usan formas específicas ("http 401") a propósito: un "401" suelto
		// podría aparecer dentro de otro mensaje sin ser un problema de auth.
		"http 401",
		"status 401",
		"unauthorized",
		// El scrape del client_id falló por completo (la página y sus bundles no
		// traen el patrón): la fuente no puede servir hasta que SoundCloud
		// publique otra variante, y cada reintento cuesta ~1-2s de escaneo.
		"client_id",
		"client id",
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
