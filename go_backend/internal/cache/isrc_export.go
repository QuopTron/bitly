// Punto de entrada exportado del extractor de ISRC.
//
// Qué hace: expone extractISRCFromFile (los parsers de FLAC/MP3/M4A/OGG) al
// resto del backend. Hace falta porque internal/audio LEE metadata pero no
// rellena el ISRC (solo lo ESCRIBE al etiquetar), así que la única fuente real
// de ISRC por archivo son estos parsers.
//
// Se conecta con: library.Scan, que lo usa para completar Metadata.ISRC de
// cada archivo local importado; y con cache.BuildIndex, que ya lo usa dentro
// del propio paquete.
package cache

// ExtraerISRCDeArchivo devuelve el ISRC de un archivo de audio junto con una
// referencia mínima (título, artista, álbum) leída del propio archivo.
// Devuelve "" y nil cuando el formato no está soportado o no trae ISRC.
func ExtraerISRCDeArchivo(ruta string) (string, *TrackRef) {
	return extractISRCFromFile(ruta)
}
