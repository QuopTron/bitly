// ─────────────────────────────────────────────────────────────
// duracion_mp4.go — Duración REAL de MP4/M4A leyendo el átomo moov→mvhd.
//
// Por qué existe: la duración se estimaba con "tamaño ÷ 256 kbps", que
// inventaba el número (y el guard anti-preview de descargas rechazaba
// canciones completas por esa invención). El propio contenedor declara la
// duración: mvhd trae timescale (unidades por segundo) y duration, así que la
// duración real es duration/timescale.
//
// Se conecta con: formats.go (readMP4).
// Parte del flujo: lectura de metadata de audio.
// ─────────────────────────────────────────────────────────────

package audio

import (
	"encoding/binary"
	"io"
	"os"
)

// duracionMP4 recorre los átomos de nivel superior hasta encontrar moov (o un
// mvhd suelto, que también ocurre en archivos fragmentados) y devuelve la
// duración en milisegundos que declara el archivo.
func duracionMP4(f *os.File) (int64, bool) {
	tam, err := f.Seek(0, io.SeekEnd)
	if err != nil {
		return 0, false
	}
	var pos int64
	cabecera := make([]byte, 16)
	for pos+8 <= tam {
		if _, err := f.ReadAt(cabecera[:8], pos); err != nil {
			return 0, false
		}
		atomSize := int64(binary.BigEndian.Uint32(cabecera[:4]))
		atomType := string(cabecera[4:8])
		inicioDatos := int64(8)
		if atomSize == 1 {
			if _, err := f.ReadAt(cabecera[:16], pos); err != nil {
				return 0, false
			}
			atomSize = int64(binary.BigEndian.Uint64(cabecera[8:16]))
			inicioDatos = 16
		} else if atomSize == 0 {
			atomSize = tam - pos
		}
		if atomSize < 8 || pos+atomSize > tam {
			return 0, false
		}
		switch atomType {
		case "moov":
			if ms, ok := buscarMvhd(f, pos+inicioDatos, pos+atomSize); ok {
				return ms, true
			}
		case "mvhd":
			if ms, ok := leerMvhd(f, pos+inicioDatos, pos+atomSize); ok {
				return ms, true
			}
		}
		pos += atomSize
	}
	return 0, false
}

// buscarMvhd recorre los átomos hijos de moov buscando mvhd.
func buscarMvhd(f *os.File, desde, hasta int64) (int64, bool) {
	cabecera := make([]byte, 8)
	for pos := desde; pos+8 <= hasta; {
		if _, err := f.ReadAt(cabecera, pos); err != nil {
			return 0, false
		}
		atomSize := int64(binary.BigEndian.Uint32(cabecera[:4]))
		atomType := string(cabecera[4:8])
		if atomSize < 8 || pos+atomSize > hasta {
			return 0, false
		}
		if atomType == "mvhd" {
			return leerMvhd(f, pos+8, pos+atomSize)
		}
		pos += atomSize
	}
	return 0, false
}

// leerMvhd interpreta la versión 0 (32 bits) y la versión 1 (64 bits).
func leerMvhd(f *os.File, desde, hasta int64) (int64, bool) {
	if hasta-desde < 20 {
		return 0, false
	}
	buf := make([]byte, 32)
	n := int64(len(buf))
	if hasta-desde < n {
		n = hasta - desde
	}
	if _, err := f.ReadAt(buf[:n], desde); err != nil && n < 20 {
		return 0, false
	}
	var timescale, duration uint64
	if buf[0] == 1 {
		if n < 28 {
			return 0, false
		}
		timescale = uint64(binary.BigEndian.Uint32(buf[20:24]))
		duration = binary.BigEndian.Uint64(buf[24:32])
	} else {
		timescale = uint64(binary.BigEndian.Uint32(buf[12:16]))
		duration = uint64(binary.BigEndian.Uint32(buf[16:20]))
	}
	if timescale == 0 || duration == 0 {
		return 0, false
	}
	return int64(duration * 1000 / timescale), true
}
