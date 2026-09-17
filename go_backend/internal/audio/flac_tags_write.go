// ─────────────────────────────────────────────────────────────
// flac_tags_write.go — Escritura de etiquetas de un FLAC con COMENTARIOS
// VORBIS, que es el bloque que el formato define para esto (tipo 4).
//
// Por qué existe: el escritor usaba APE tags (ver metadata_write_native.go).
// Un FLAC no lleva APE: el bloque que se le agregaba no lo lee ningún
// reproductor —ni el propio lector de la app, que lee Vorbis— así que el
// archivo terminaba con etiquetas invisibles y, en el peor caso, con el
// audio corrupto. Acá se reemplaza SOLO el bloque de comentarios y se deja el
// resto intacto: STREAMINFO, portada y los fotogramas de audio no se tocan.
//
// Cómo: se recorren los bloques de metadata tras "fLaC" (cabecera de 4 bytes:
// último + tipo + tamaño de 24 bits), se guarda todo tal cual, se arma un
// bloque de comentarios nuevo y se reengancha el audio. La escritura es
// atómica (SafeSaveFLAC), así que un corte de energía no deja a medias el
// archivo ya descargado.
//
// Se conecta con: metadata_write_native.go (escribirMetadataFLAC).
// Parte del flujo: descargas (etiquetado del archivo bajado).
// ─────────────────────────────────────────────────────────────

package audio

import (
	"encoding/binary"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// camposGestionados son las claves que la app escribe. Las demás etiquetas que
// ya traía el archivo (ENCODER, COMMENT, REPLAYGAIN_*) se conservan: no son
// nuestras y borrarlas sería perder información del usuario.
var camposGestionados = map[string]bool{
	"TITLE": true, "ARTIST": true, "ALBUM": true, "ALBUMARTIST": true,
	"GENRE": true, "ISRC": true, "DATE": true, "TRACKNUMBER": true,
	"TRACKTOTAL": true, "TOTALTRACKS": true, "DISCNUMBER": true,
}

// bloqueMetaFLAC es un bloque de metadata con su tipo y su cuerpo ya armado.
type bloqueMetaFLAC struct {
	tipo   byte
	cuerpo []byte
}

// escribirMetadataFLACVorbis reemplaza los comentarios Vorbis de [path] por los
// que salen de [meta], conservando el resto del archivo.
func escribirMetadataFLACVorbis(path string, meta *Metadata) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if len(data) < 8 || string(data[0:4]) != "fLaC" {
		return fmt.Errorf("ERR_AUDIO_WRITE: %s no es un FLAC", path)
	}
	bloques, vendor, previos, audio, err := partirFLAC(data)
	if err != nil {
		return err
	}
	if len(bloques) == 0 || bloques[0].tipo != 0 {
		// Sin STREAMINFO no hay FLAC válido: mejor no tocar nada.
		return fmt.Errorf("ERR_AUDIO_WRITE: %s sin STREAMINFO", path)
	}
	nuevo := bloqueComentarios(vendor, comentariosDe(meta, previos))
	// El bloque de comentarios va SIEMPRE después de STREAMINFO (posición que
	// esperan los lectores y que la convención del formato pide).
	salida := []bloqueMetaFLAC{bloques[0], nuevo}
	salida = append(salida, bloques[1:]...)
	return SafeSaveFLAC(path, armarFLAC(salida, audio))
}

// partirFLAC separa el archivo en bloques de metadata, el audio y los datos del
// bloque de comentarios que ya tuviera (vendor y entradas).
func partirFLAC(data []byte) (bloques []bloqueMetaFLAC, vendor string, previos []string, audio []byte, err error) {
	pos := 4
	for i := 0; i < topeBloquesFLAC; i++ {
		if pos+4 > len(data) {
			return nil, "", nil, nil, fmt.Errorf("ERR_AUDIO_WRITE: metadata truncada")
		}
		ultimo := data[pos]&0x80 != 0
		tipo := data[pos] & 0x7F
		tamano := int(data[pos+1])<<16 | int(data[pos+2])<<8 | int(data[pos+3])
		pos += 4
		if tamano < 0 || pos+tamano > len(data) {
			return nil, "", nil, nil, fmt.Errorf("ERR_AUDIO_WRITE: bloque de %d bytes fuera del archivo", tamano)
		}
		cuerpo := data[pos : pos+tamano]
		pos += tamano
		if tipo == bloqueComentariosVorbis {
			// El bloque viejo se descarta (se reemplaza) pero su vendor y las
			// entradas ajenas se reaprovechan.
			vendor, previos = leerComentarios(cuerpo)
		} else {
			bloques = append(bloques, bloqueMetaFLAC{tipo: tipo, cuerpo: cuerpo})
		}
		if ultimo {
			return bloques, vendor, previos, data[pos:], nil
		}
	}
	return nil, "", nil, nil, fmt.Errorf("ERR_AUDIO_WRITE: demasiados bloques de metadata")
}

// leerComentarios devuelve el vendor y las entradas "CLAVE=valor" del bloque.
func leerComentarios(cuerpo []byte) (string, []string) {
	if len(cuerpo) < 8 {
		return "", nil
	}
	vendorLen := int(binary.LittleEndian.Uint32(cuerpo[0:4]))
	off := 4 + vendorLen
	if vendorLen < 0 || off+4 > len(cuerpo) {
		return "", nil
	}
	vendor := string(cuerpo[4 : 4+vendorLen])
	cantidad := int(binary.LittleEndian.Uint32(cuerpo[off : off+4]))
	off += 4
	entradas := make([]string, 0, cantidad)
	for i := 0; i < cantidad; i++ {
		if off+4 > len(cuerpo) {
			break
		}
		largo := int(binary.LittleEndian.Uint32(cuerpo[off : off+4]))
		off += 4
		if largo < 0 || off+largo > len(cuerpo) {
			break
		}
		entradas = append(entradas, string(cuerpo[off:off+largo]))
		off += largo
	}
	return vendor, entradas
}

// comentariosDe arma la lista final: primero los campos que la app conoce (los
// que tengan valor) y después las etiquetas ajenas que ya traía el archivo.
func comentariosDe(meta *Metadata, previos []string) []string {
	var salida []string
	agregar := func(clave, valor string) {
		if strings.TrimSpace(valor) != "" {
			salida = append(salida, clave+"="+valor)
		}
	}
	agregar("TITLE", meta.Title)
	agregar("ARTIST", meta.Artist)
	agregar("ALBUM", meta.Album)
	agregar("ALBUMARTIST", meta.AlbumArtist)
	agregar("GENRE", meta.Genre)
	agregar("ISRC", strings.ToUpper(meta.ISRC))
	if meta.Year > 0 {
		agregar("DATE", strconv.Itoa(meta.Year))
	}
	if meta.TrackNumber > 0 {
		agregar("TRACKNUMBER", strconv.Itoa(meta.TrackNumber))
	}
	if meta.TrackTotal > 0 {
		agregar("TRACKTOTAL", strconv.Itoa(meta.TrackTotal))
	}
	if meta.DiscNumber > 0 {
		agregar("DISCNUMBER", strconv.Itoa(meta.DiscNumber))
	}
	for _, entrada := range previos {
		clave, _, ok := strings.Cut(entrada, "=")
		if !ok || camposGestionados[strings.ToUpper(strings.TrimSpace(clave))] {
			continue
		}
		salida = append(salida, entrada)
	}
	return salida
}
