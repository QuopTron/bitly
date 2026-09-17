// ─────────────────────────────────────────────────────────────
// flac_tags_read.go — Lectura de los comentarios Vorbis y la portada de
// un FLAC, que es donde el formato guarda título, artista, álbum, ISRC…
//
// Por qué existe: readFLAC solo miraba el bloque STREAMINFO (duración,
// sample rate, bit depth), así que para CUALQUIER FLAC la metadata salía
// vacía. Consecuencia real: no se podía saber si un archivo ya traía las
// etiquetas del catálogo, y el escritor (que usa APE tags en vez de
// comentarios Vorbis, ver metadata_write_native.go) terminaba reescribiendo
// 20 MB para nada y dejando el archivo irreproducible.
//
// Cómo: se recorren los bloques de metadata después de "fLaC" (cabecera de
// 4 bytes: último + tipo + tamaño de 24 bits) y se leen los de tipo 4
// (VORBIS_COMMENT) y 6 (PICTURE). El recorrido corta en el primer bloque
// marcado como último.
//
// Se conecta con: formats.go (readFLAC) y download/etiquetas_descarga.go
// (yaTieneEtiquetas).
// Parte del flujo: lectura de metadata de un archivo descargado.
// ─────────────────────────────────────────────────────────────

package audio

import (
	"encoding/binary"
	"io"
	"os"
	"strings"
)

const (
	// bloqueComentariosVorbis es el tipo de bloque con las etiquetas de texto.
	bloqueComentariosVorbis = 4
	// bloquePortada es el tipo de bloque con una imagen incrustada.
	bloquePortada = 6
	// topeBloquesFLAC acota el recorrido: un archivo con metadata absurda
	// (o corrupta) no puede hacer perder tiempo al backend.
	topeBloquesFLAC = 64
)

// leerEtiquetasFLAC completa [meta] con los comentarios Vorbis y la portada que
// tenga el archivo. Es best-effort: cualquier problema deja lo ya leído.
func leerEtiquetasFLAC(f *os.File, meta *Metadata) {
	if _, err := f.Seek(4, io.SeekStart); err != nil { // salta "fLaC"
		return
	}
	for i := 0; i < topeBloquesFLAC; i++ {
		cabecera := make([]byte, 4)
		if _, err := io.ReadFull(f, cabecera); err != nil {
			return
		}
		ultimo := cabecera[0]&0x80 != 0
		tipo := cabecera[0] & 0x7F
		tamano := int(cabecera[1])<<16 | int(cabecera[2])<<8 | int(cabecera[3])
		if tamano <= 0 {
			if ultimo {
				return
			}
			continue
		}
		cuerpo := make([]byte, tamano)
		if _, err := io.ReadFull(f, cuerpo); err != nil {
			return
		}
		switch tipo {
		case bloqueComentariosVorbis:
			aplicarComentariosVorbis(cuerpo, meta)
		case bloquePortada:
			meta.HasCover = true
		}
		if ultimo {
			return
		}
	}
}

// aplicarComentariosVorbis interpreta el bloque VORBIS_COMMENT, que es una
// lista de "CLAVE=valor" en little-endian (proveedor, cantidad, y cada entrada
// con su tamaño). Las claves se comparan sin importar mayúsculas.
func aplicarComentariosVorbis(cuerpo []byte, meta *Metadata) {
	if len(cuerpo) < 8 {
		return
	}
	vendorLen := int(binary.LittleEndian.Uint32(cuerpo[0:4]))
	off := 4 + vendorLen
	if off+4 > len(cuerpo) {
		return
	}
	cantidad := int(binary.LittleEndian.Uint32(cuerpo[off : off+4]))
	off += 4
	for i := 0; i < cantidad; i++ {
		if off+4 > len(cuerpo) {
			return
		}
		largo := int(binary.LittleEndian.Uint32(cuerpo[off : off+4]))
		off += 4
		if largo < 0 || off+largo > len(cuerpo) {
			return
		}
		entrada := string(cuerpo[off : off+largo])
		off += largo
		clave, valor, ok := strings.Cut(entrada, "=")
		if !ok {
			continue
		}
		aplicarCampoVorbis(strings.ToUpper(strings.TrimSpace(clave)), valor, meta)
	}
}

// aplicarCampoVorbis vuelca un comentario en el campo correspondiente. Solo se
// llena lo que está vacío, para que el primer valor gane.
func aplicarCampoVorbis(clave, valor string, meta *Metadata) {
	valor = strings.TrimSpace(valor)
	if valor == "" {
		return
	}
	switch clave {
	case "TITLE":
		if meta.Title == "" {
			meta.Title = valor
		}
	case "ARTIST":
		if meta.Artist == "" {
			meta.Artist = valor
		}
	case "ALBUM":
		if meta.Album == "" {
			meta.Album = valor
		}
	case "ALBUMARTIST", "ALBUM ARTIST":
		if meta.AlbumArtist == "" {
			meta.AlbumArtist = valor
		}
	case "ISRC":
		if meta.ISRC == "" {
			meta.ISRC = strings.ToUpper(valor)
		}
	case "GENRE":
		if meta.Genre == "" {
			meta.Genre = valor
		}
	}
}
