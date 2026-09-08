// Package cooldown implementa un circuit breaker ligero por provider.
//
// Los providers que reciben rate-limit (HTTP 429), están temporalmente
// no disponibles, o solo devuelven resultados encriptados no reproducibles se
// "enfrían" por una ventana para que los bucles de search/fallback/prefetch no
// martilleen su API en cada track. Un provider enfriado se salta rápido, y cada
// error nuevo que coincide con los marcadores extiende la ventana con backoff
// exponencial acotado; una respuesta exitosa lo limpia al instante.
//
// El estado se agrupa por provider y opcionalmente por clase de operación: los
// buckets por operación (p. ej. "feed", "detail") están aislados, de modo que
// un rate-limit en una superficie (un endpoint de home-feed con 429) solo
// enfría esa superficie y no deshabilita el provider en playback/search/
// download — y viceversa.
package cooldown

import (
	"sync"
	"time"
)

const (
	// duracionCooldown es la ventana inicial tras un único evento de rate-limit.
	duracionCooldown = 90 * time.Second
	// duracionCooldownVerificacion es la ventana tras VERIFY_REQUIRED (sesión
	// firmada / challenge Cloudflare pendiente) — más corta que la de
	// rate-limit para reintentar rápido tras completar la verificación.
	duracionCooldownVerificacion = 45 * time.Second
	// duracionCooldownMax limita el backoff exponencial entre eventos repetidos.
	duracionCooldownMax = 8 * time.Minute
)

var (
	mutex     sync.Mutex
	enfriados = map[string]time.Time{}
)

// claveOp mapea un provider + clase de operación a su bucket de cooldown.
func claveOp(nombre, op string) string {
	if op == "" {
		return nombre
	}
	return nombre + ":" + op
}

// IsCooled reporta si [name] está enfriándose a nivel provider.
func IsCooled(name string) bool {
	return estaEnCooldown(claveOp(name, ""))
}

// IsCooledOp reporta si [name] está en cooldown dentro de la clase de operación [op].
func IsCooledOp(name, op string) bool {
	return estaEnCooldown(claveOp(name, op))
}

func estaEnCooldown(clave string) bool {
	mutex.Lock()
	defer mutex.Unlock()
	return time.Now().Before(enfriados[clave])
}
