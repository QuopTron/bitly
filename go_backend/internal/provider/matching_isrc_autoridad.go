package provider

import "strings"

// matching_isrc_autoridad.go — Quién puede dar fe de un ISRC.
//
// Por qué existe: un ISRC identifica una grabación EXACTA. Pero no todos los
// proveedores lo OBTIENEN de la misma forma:
//
//   - Los catálogos (Deezer, Qobuz, Tidal, Amazon, Apple Music) lo reciben del
//     sello: su `isrc` viene en la metadata del propio track. Ahí un ISRC que
//     coincide ES la misma grabación.
//   - Los re-subidos (YouTube / YouTube Music / SoundCloud) NO publican ISRC. Lo
//     infieren por parecido de nombre contra Deezer (título + artista +
//     duración), así que un ISRC "declarado" por ellos NO prueba identidad: un
//     remix con el mismo título y una duración parecida recibe el ISRC del
//     original y pasaba la verificación.
//   - flac-rescue (rescate por ISRC) no tiene catálogo propio: su título ES el
//     ISRC, y su contrato es "ISRC entra, audio exacto sale".
//
// Consecuencia práctica: aceptar un candidato solo porque declara el ISRC pedido
// es correcto en los catálogos y en flac-rescue, y es un error en los re-subidos.
// Este archivo centraliza esa distinción para que streaming y descarga usen la
// MISMA regla (antes cada ruta decidía por su cuenta y dejaba pasar re-subidos).
//
// Se conecta con: streaming/play_verify.go, download/orchestrator_verify.go y
// provider/extension_download_helpers.go (búsqueda por ISRC).
// Parte del flujo: identificación de la canción buscada entre fuentes.

// proveedoresAutoritativosISRC son los proveedores cuyo `isrc` viene del sello
// (catálogo) o cuyo índice ES el ISRC. Un ISRC que coincide en ellos se acepta
// como identidad exacta aunque el título difiera.
var proveedoresAutoritativosISRC = map[string]bool{
	"deezer":      true,
	"deezer-web":  true,
	"qobuz":       true,
	"qobuz-web":   true,
	"tidal":       true,
	"tidal-web":   true,
	"amazon":      true,
	"amazon-web":  true,
	"apple-music": true,
	"apple":       true,
	"flac-rescue": true,
	"musicbrainz": true,
}

// EsProveedorAutoritativoISRC reporta si [nombre] puede dar fe de un ISRC. Los
// proveedores que no están en la lista (YouTube, YouTube Music, SoundCloud)
// infieren el ISRC por nombre: con ellos nunca se acepta la identidad solo por
// el ISRC declarado.
func EsProveedorAutoritativoISRC(nombre string) bool {
	return proveedoresAutoritativosISRC[strings.TrimSpace(nombre)]
}

// PreferirISRC deja primero los candidatos que declaran [isrc] (la misma
// grabación) sin descartar al resto: SoundCloud y YouTube no siempre exponen
// ISRC, así que un candidato sin ISRC sigue siendo válido como último recurso.
// Es estable: dentro de cada grupo se conserva el orden recibido.
func PreferirISRC(isrc string, cands []TrackResult) []TrackResult {
	pedido := strings.TrimSpace(strings.ToUpper(isrc))
	if pedido == "" || len(cands) < 2 {
		return cands
	}
	coinciden := make([]TrackResult, 0, len(cands))
	resto := make([]TrackResult, 0, len(cands))
	for _, c := range cands {
		if strings.TrimSpace(strings.ToUpper(c.ISRC)) == pedido {
			coinciden = append(coinciden, c)
			continue
		}
		resto = append(resto, c)
	}
	if len(coinciden) == 0 {
		return cands
	}
	return append(coinciden, resto...)
}

// EsCandidatoPorISRC reporta si [t] es una coincidencia EXACTA por ISRC aunque
// no traiga metadata de catálogo. Los proveedores indexados por ISRC
// (flac-rescue) devuelven el propio ISRC como título y sin artista, así que no
// pueden pasar la verificación de título/artista aunque SÍ sean la grabación
// pedida. Se exige que el ISRC declarado sea el mismo que se pidió.
func EsCandidatoPorISRC(isrc string, t *TrackResult) bool {
	if t == nil {
		return false
	}
	pedido := strings.TrimSpace(strings.ToUpper(isrc))
	declarado := strings.TrimSpace(strings.ToUpper(t.ISRC))
	if pedido == "" || declarado == "" || pedido != declarado {
		return false
	}
	titulo := strings.TrimSpace(t.Title)
	return titulo == "" || strings.EqualFold(titulo, strings.TrimSpace(isrc))
}
