// ─────────────────────────────────────────────────────────────
// play_fuentes_credenciales.go — Le dice a la carrera de reproducción
// qué fuentes pueden streamear AHORA (según las credenciales guardadas).
//
// Qué problema resuelve: la política de fuentes de audio excluía a los
// catálogos (deezer, qobuz-web, tidal-web, amazon…) porque sin sesión no
// resuelven una URL y sondearlos gastaba 1,5-5,8s por turno devolviendo nada.
// Eso es cierto SIN credenciales, pero deja el FLAC de Deezer/Qobuz/Tidal
// afuera también cuando el usuario SÍ las tiene (propias o del pool) — el
// audio de esas fuentes solo aparecía en las DESCARGAS.
//
// Qué hace: instala en streaming un predicado que mira las credenciales ya
// guardadas (Ajustes → Credenciales) y una sesión firmada usable. Con eso, la
// carrera suma a esas fuentes por su cuenta (últimas en pérdida, primeras en
// sin pérdida cuando pueden dar FLAC) y, sin credenciales, la carrera queda
// EXACTAMENTE como estaba.
//
// Se conecta con: streaming.SetFuenteStreameable (rescue_order.go) y
// config_candado.go (los ajustes por extensión).
// Parte del flujo: reproducción (elección de fuente de audio).
// ─────────────────────────────────────────────────────────────

package gobackend

import "github.com/zarz/bitly/go_backend/internal/streaming"

func init() {
	streaming.SetFuenteStreameable(credencialesDeExtension)
}

// credencialesDeExtension reporta si [name] puede resolver audio en vivo con lo
// que el usuario tiene configurado. Solo cubre las fuentes cuyo audio propio
// depende de una cuenta; las anónimas (YouTube/YTMusic, Internet Archive,
// flac-rescue) no pasan por acá porque ya están en la lista fija.
func credencialesDeExtension(name string) bool {
	// Una sesión firmada usable (mecanismo zarz) ya es una credencial válida.
	if signedSessionSourceReady(name) {
		return true
	}
	switch name {
	case "deezer":
		return ajusteExtensionNoVacio(name, "arl", "arlPool")
	case "tidal-web", "tidal":
		return ajusteExtensionNoVacio(name, "tidalAccessToken", "tidalTokenPool")
	case "qobuz-web", "qobuz":
		// El pool ya trae "email:password"; las credenciales sueltas valen
		// solo si están las DOS (una sola no autentica).
		return ajusteExtensionNoVacio(name, "qobuzPool") ||
			(ajusteExtensionNoVacio(name, "email") && ajusteExtensionNoVacio(name, "password"))
	default:
		// Amazon y Pandora NO tienen audio propio que este backend pueda
		// servir: el `getDownloadUrl` de Amazon devuelve null y su `download`
		// solo funciona con un respaldo firmado; su fuente "abierta" (SongLink
		// → Deezer/Spotify, songstats) sirve para IDENTIFICAR la pista (el
		// ASIN), no para entregar bytes. Meterlas en la carrera sería sondear
		// una fuente que nunca puede ganar. Su lugar es la identidad y el
		// rescate por ISRC de las fuentes que sí streamean.
		return false
	}
}
