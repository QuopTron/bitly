package gobackend

import "strings"

// ─────────────────────────────────────────────────────────────────────────
// QUÉ ES (Y QUÉ NO ES) UNA FUENTE DE BÚSQUEDA
//
// El registro de proveedores mezcla dos cosas distintas:
//
//  1. CATÁLOGOS: deezer, apple-music, soundcloud, spotify-web, qobuz-web,
//     tidal-web, ytmusic-spotiflac, amazon... Son para lo que el usuario abre
//     la búsqueda: encontrar canciones, álbumes, artistas y playlists.
//  2. RESPALDO: flac-rescue, internetarchive, soulseek, redacted y
//     musicbrainz no son catálogos navegables. Existen para que el pipeline de
//     reproducción/descarga consiga el FLAC exacto detrás de un ISRC
//     (los tres primeros), para traer metadata (musicbrainz), o para pedir la
//     canción a un torrent privado (redacted).
//
// Meter los segundos en la búsqueda era el bug: al buscar aparecían
// "resultados" de Internet Archive que no se pueden ofrecer como fuente, y el
// usuario no tenía forma de saber que ese no era un catálogo. Peor: gastaban
// tiempo de la ventana de búsqueda compitiendo contra los catálogos reales.
//
// Por eso quedan fuera de la búsqueda —pero SOLO de la búsqueda: siguen
// registrados y el rescate los usa igual (ver streaming/play_types.go y
// download/orchestrator_fallback.go). Sacarlos del registro rompería el
// fallback lossless; sacarlos de la búsqueda es lo correcto.
// ─────────────────────────────────────────────────────────────────────────

// fuentesSoloRespaldo son los ids de proveedor que NO se ofrecen como fuente
// de búsqueda. Se comparan plegados a minúsculas.
var fuentesSoloRespaldo = map[string]bool{
	"flac-rescue":     true, // rescate FLAC por ISRC/duración, sin catálogo propio
	"internetarchive": true, // catálogo abierto usado para rescatar lossless
	"soulseek":        true, // P2P; su búsqueda es por nombre de archivo, no por catálogo
	"redacted":        true, // torrent privado de FLAC
	"musicbrainz":     true, // solo metadata/ISRC, no entrega audio
	// Last.fm es la capa de IDENTIDAD: nombres canónicos y el video oficial
	// de YouTube. No entrega audio, así que no es un catálogo que se le pueda
	// ofrecer al usuario; trabaja por dentro (ver provider/lastfm).
	"lastfm": true,
}

// esFuenteDeBusqueda dice si un proveedor puede ofrecerse/evaluarse como fuente
// de búsqueda. El id vacío se trata como verdadero porque significa "todas las
// fuentes" (el walk multi-fuente): el filtro se aplica proveedor por proveedor
// unas líneas más abajo.
func esFuenteDeBusqueda(id string) bool {
	if strings.TrimSpace(id) == "" {
		return true
	}
	return !fuentesSoloRespaldo[strings.ToLower(strings.TrimSpace(id))]
}
