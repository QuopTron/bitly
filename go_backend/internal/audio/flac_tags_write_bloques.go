// ─────────────────────────────────────────────────────────────
// flac_tags_write_bloques.go — Armado de bloques de un FLAC.
//
// Separado de flac_tags_write.go para que ahí quede la DECISIÓN (qué
// etiquetas se escriben) y acá la PLOMERÍA del formato: el bloque de
// comentarios Vorbis y el reensamblado con las cabeceras correctas.
//
// La cabecera de cada bloque son 4 bytes: último (bit 7) + tipo (bits 0-6) +
// tamaño de 24 bits en big-endian. Equivocarla es lo que dejaba archivos
// irreproducibles, así que el armado se hace en un solo lugar.
// ─────────────────────────────────────────────────────────────

package audio

import "encoding/binary"

// bloqueComentarios arma el bloque VORBIS_COMMENT (tipo 4) con [entradas]
// ("CLAVE=valor") y el [vendor] que ya traía el archivo (o "bitly" si no había).
func bloqueComentarios(vendor string, entradas []string) bloqueMetaFLAC {
	if vendor == "" {
		vendor = "bitly"
	}
	cuerpo := make([]byte, 0, 64)
	cuerpo = append(cuerpo, bytesUint32(uint32(len(vendor)))...)
	cuerpo = append(cuerpo, vendor...)
	cuerpo = append(cuerpo, bytesUint32(uint32(len(entradas)))...)
	for _, entrada := range entradas {
		cuerpo = append(cuerpo, bytesUint32(uint32(len(entrada)))...)
		cuerpo = append(cuerpo, entrada...)
	}
	return bloqueMetaFLAC{tipo: bloqueComentariosVorbis, cuerpo: cuerpo}
}

// armarFLAC reensambla el archivo: "fLaC" + bloques (con sus cabeceras) +
// audio. Marca el último bloque antes del audio, que es lo que hace que un
// lector sepa dónde termina la metadata.
func armarFLAC(bloques []bloqueMetaFLAC, audio []byte) []byte {
	salida := make([]byte, 0, len(audio)+256)
	salida = append(salida, 'f', 'L', 'a', 'C')
	for i, b := range bloques {
		tamano := len(b.cuerpo)
		cabecera := []byte{b.tipo & 0x7F, byte(tamano >> 16), byte(tamano >> 8), byte(tamano)}
		if i == len(bloques)-1 {
			cabecera[0] |= 0x80
		}
		salida = append(salida, cabecera...)
		salida = append(salida, b.cuerpo...)
	}
	salida = append(salida, audio...)
	return salida
}

// bytesUint32 serializa en little-endian, que es el orden de los comentarios
// Vorbis (a diferencia de la cabecera del bloque, que es big-endian).
func bytesUint32(v uint32) []byte {
	b := make([]byte, 4)
	binary.LittleEndian.PutUint32(b, v)
	return b
}
