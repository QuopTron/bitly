// ─────────────────────────────────────────────────────────────
// qobuz_diagnostico.go — Informe del POOL de sesiones de Qobuz.
//
// Por qué existe: cuando el pool de Qobuz queda vacío, la descarga directa se
// apaga y el usuario no ve nada — la app sigue funcionando por los otros
// canales y no hay forma de saber si el problema es "el endpoint no responde"
// (fuente caída) o "el endpoint responde pero no hay tokens vivos" (sin
// tokens). Son dos arreglos distintos y el síntoma es el mismo.
//
// Qué hace: recorre el MISMO camino que la expansión real del pool
// (descargar fuentes → extraer → validar) y traduce el resultado a un estado y
// un texto en castellano. Es SOLO LECTURA: no toca los ajustes guardados.
//
// Se conecta con: gobackend (la acción `estadoPool` de qobuz-web, que la
// interfaz de Ajustes consulta) y pool.go (ConstruirPool, el mismo núcleo que
// usa la expansión real, para que el informe no mienta).
// Parte del flujo: Ajustes → Descargas → pool de Qobuz.
// ─────────────────────────────────────────────────────────────

package sessionpool

import (
	"net/http"
	"time"
)

// Estados posibles del informe. Son estables: la interfaz los usa para pintar
// el resultado.
const (
	// EstadoPoolSinFuentes: ni el usuario ni la fábrica dejaron una URL.
	EstadoPoolSinFuentes = "sin_fuentes"
	// EstadoPoolFuenteCaida: hay fuentes, pero NINGUNA se pudo descargar.
	EstadoPoolFuenteCaida = "fuente_caida"
	// EstadoPoolSinTokens: las fuentes se bajaron, pero no quedó ninguna
	// credencial usable (el endpoint responde, pero su lista está vacía o muerta).
	EstadoPoolSinTokens = "sin_tokens"
	// EstadoPoolOk: hay al menos una credencial usable.
	EstadoPoolOk = "ok"
)

// DiagnosticoPool es el informe que consume la interfaz.
type DiagnosticoPool struct {
	Estado        string   `json:"estado"`
	Fuentes       int      `json:"fuentes"`
	FuentesCaidas []string `json:"fuentesCaidas"`
	Usables       int      `json:"usables"`
	Descartadas   int      `json:"descartadas"`
	Ms            int64    `json:"ms"`
	Detalle       string   `json:"detalle"`
}

// DiagnosticoPoolQobuz recorre el pool y devuelve su estado real. [propias] son
// las credenciales del usuario (siempre primero y sin validar) y [fuentes] las
// URLs a descargar (ya resueltas por el llamador, default incluido).
//
// [loginURL]/[favoritosURL] se inyectan igual que en ConstruirPoolQobuz: con ""
// se usan los endpoints reales de Qobuz; los tests los apuntan a un servidor
// local para no salir a la red.
func DiagnosticoPoolQobuz(cliente *http.Client, propias, fuentes []string, loginURL, favoritosURL string) DiagnosticoPool {
	inicio := time.Now()
	if len(fuentes) == 0 {
		return DiagnosticoPool{
			Estado: EstadoPoolSinFuentes,
			Ms:     time.Since(inicio).Milliseconds(),
			Detalle: "No hay ninguna URL de pool configurada y el origen de fábrica quedó vacío. " +
				"Pegá una URL en el pool o revisá que el endpoint esté publicado.",
		}
	}

	res := ConstruirPoolQobuz(cliente, propias, fuentes, loginURL, favoritosURL)
	diag := DiagnosticoPool{
		Fuentes:       len(fuentes),
		FuentesCaidas: res.FuentesCaidas,
		Usables:       len(res.Usables),
		Descartadas:   res.Descartadas,
		Ms:            time.Since(inicio).Milliseconds(),
	}

	switch {
	case len(res.Usables) > 0:
		diag.Estado = EstadoPoolOk
		diag.Detalle = "El pool tiene credenciales vivas: la descarga directa de Qobuz " +
			"funciona con estas sesiones."
	case len(res.FuentesCaidas) == len(fuentes):
		// Todas las URLs fallaron: el problema es el endpoint, no las cuentas.
		diag.Estado = EstadoPoolFuenteCaida
		diag.Detalle = "Ninguna fuente del pool se pudo descargar: el endpoint no responde " +
			"(o responde con error). Revisá la URL y que el Worker esté publicado."
	default:
		// Una fuente respondió, pero sin credenciales usables.
		diag.Estado = EstadoPoolSinTokens
		diag.Detalle = "Las fuentes respondieron, pero no quedó ninguna sesión de Qobuz usable: " +
			"revisá que el endpoint publique tokens vivos (una cuenta con suscripción)."
	}
	return diag
}
